package com.example.streetdrop

import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import com.solana.mobilewalletadapter.clientlib.*
import com.solana.mobilewalletadapter.clientlib.protocol.MobileWalletAdapterClient.AuthorizationResult
import org.bitcoinj.core.Base58
import java.io.ByteArrayOutputStream

class MainActivity : FlutterFragmentActivity() {
    private val WALLET_CHANNEL = "com.streetdrop/wallet"
    private val ADMIN_WALLET   = "CoDEFunNNjkntxH7jQzSf6ZvRyS3RRdz5AYmHNVsC6RQ"
    private val scope          = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private val identity = ConnectionIdentity(
        Uri.parse("https://streetdrop.xyz"),
        Uri.parse("https://streetdrop.xyz/icon.png"),
        "StreetDrop"
    )

    private fun createMwa(): MobileWalletAdapter {
        val mwa = MobileWalletAdapter(identity, 90_000)
        mwa.blockchain = Solana.Devnet
        return mwa
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WALLET_CHANNEL)
            .setMethodCallHandler { call, result ->
                scope.launch {
                    try {
                        when (call.method) {

                            "checkSeedVault" -> {
                                val mwa = createMwa()
                                val sender = ActivityResultSender(this@MainActivity)
                                when (val txResult = mwa.connect(sender)) {
                                    is TransactionResult.Success -> {
                                        val address = Base58.encode(txResult.authResult.publicKey)
                                        withContext(Dispatchers.Main) {
                                            result.success(mapOf(
                                                "available" to true,
                                                "address" to address,
                                                "walletName" to "Seed Vault"
                                            ))
                                        }
                                    }
                                    else -> {
                                        withContext(Dispatchers.Main) {
                                            result.success(mapOf("available" to false))
                                        }
                                    }
                                }
                            }

                            "connectWallet" -> {
                                val mwa = createMwa()
                                val sender = ActivityResultSender(this@MainActivity)
                                when (val txResult = mwa.connect(sender)) {
                                    is TransactionResult.Success -> {
                                        val auth = txResult.authResult
                                        val address = Base58.encode(auth.publicKey)
                                        val walletName = auth.walletUriBase?.toString() ?: "unknown"
                                        withContext(Dispatchers.Main) {
                                            result.success(mapOf(
                                                "address" to address,
                                                "walletName" to walletName
                                            ))
                                        }
                                    }
                                    is TransactionResult.NoWalletFound -> {
                                        withContext(Dispatchers.Main) {
                                            result.error("NO_WALLET", txResult.message, null)
                                        }
                                    }
                                    is TransactionResult.Failure -> {
                                        val msg = txResult.message
                                        withContext(Dispatchers.Main) {
                                            when {
                                                msg.contains("cancel", true) ||
                                                msg.contains("reject", true) ->
                                                    result.error("USER_CANCELLED", "Cancelled", null)
                                                else ->
                                                    result.error("CONNECT_ERROR", msg, null)
                                            }
                                        }
                                    }
                                }
                            }

                            "signAndSendFee" -> {
                                val fromWallet = call.argument<String>("fromWallet")!!
                                val lamports   = (call.argument<Int>("lamports") ?: 0).toLong()
                                val rpcUrl     = call.argument<String>("rpcUrl")
                                    ?: "https://api.devnet.solana.com"

                                val mwa = createMwa()
                                val sender = ActivityResultSender(this@MainActivity)
                                val txResult = mwa.transact(sender) { _ ->
                                    val txBytes = buildTransferTx(
                                        fromWallet, ADMIN_WALLET, lamports, rpcUrl
                                    )
                                    val signResult = signAndSendTransactions(
                                        arrayOf(txBytes),
                                        DefaultTransactionParams
                                    )
                                    Base58.encode(signResult.signatures[0])
                                }
                                when (txResult) {
                                    is TransactionResult.Success -> {
                                        withContext(Dispatchers.Main) {
                                            result.success(mapOf("txSignature" to txResult.payload))
                                        }
                                    }
                                    is TransactionResult.NoWalletFound -> {
                                        withContext(Dispatchers.Main) {
                                            result.error("NO_WALLET", txResult.message, null)
                                        }
                                    }
                                    is TransactionResult.Failure -> {
                                        withContext(Dispatchers.Main) {
                                            result.error("SIGN_ERROR", txResult.message, null)
                                        }
                                    }
                                }
                            }

                            else -> withContext(Dispatchers.Main) { result.notImplemented() }
                        }
                    } catch (e: Exception) {
                        withContext(Dispatchers.Main) { result.error("UNEXPECTED", e.message, null) }
                    }
                }
            }
    }

    private suspend fun buildTransferTx(
        from: String, to: String, lamports: Long, rpcUrl: String
    ): ByteArray {
        val conn = java.net.URL(rpcUrl).openConnection() as java.net.HttpURLConnection
        conn.requestMethod = "POST"
        conn.setRequestProperty("Content-Type", "application/json")
        conn.doOutput = true
        val body = """{"jsonrpc":"2.0","id":1,"method":"getLatestBlockhash","params":[{"commitment":"finalized"}]}"""
        conn.outputStream.write(body.toByteArray())
        val json = conn.inputStream.bufferedReader().readText()
        val blockhash = org.json.JSONObject(json)
            .getJSONObject("result").getJSONObject("value").getString("blockhash")

        val fromKey = Base58.decode(from)
        val toKey   = Base58.decode(to)
        val bhBytes = Base58.decode(blockhash)
        val sysKey  = ByteArray(32)

        val buf = ByteArrayOutputStream()
        buf.write(1)              // 1 signature slot
        buf.write(ByteArray(64))  // placeholder signature
        buf.write(1); buf.write(0); buf.write(1)  // header
        buf.write(3)              // 3 accounts
        buf.write(fromKey); buf.write(toKey); buf.write(sysKey)
        buf.write(bhBytes)        // recent blockhash
        buf.write(1)              // 1 instruction
        buf.write(2)              // system program index
        buf.write(2); buf.write(0); buf.write(1)  // accounts
        val data = ByteArray(12)
        data[0] = 2               // transfer instruction
        for (i in 0..7) data[4 + i] = ((lamports shr (i * 8)) and 0xFF).toByte()
        buf.write(data.size); buf.write(data)
        return buf.toByteArray()
    }

    override fun onDestroy() { scope.cancel(); super.onDestroy() }
}
