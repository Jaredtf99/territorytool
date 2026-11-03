package com.jared.territorytool.core.network

import com.jared.territorytool.R
import com.jared.territorytool.core.Strings

sealed class NetworkError(message: String) : Exception(message) {
    class InvalidUrl : NetworkError(Strings.get(R.string.error_invalid_url))
    class InvalidResponse : NetworkError(Strings.get(R.string.error_invalid_response))
    class Decoding : NetworkError(Strings.get(R.string.error_decoding))
    class Server(val serverMessage: String) : NetworkError(serverMessage)
    class Unauthorized : NetworkError(Strings.get(R.string.error_unauthorized))
    class Unknown : NetworkError(Strings.get(R.string.error_unknown))
    /** Sin red o servidor inalcanzable (el equivalente a `NSURLErrorNotConnectedToInternet`). */
    class Offline : NetworkError(Strings.get(R.string.error_offline))
}
