package com.cleaning

import io.ktor.http.ContentType
import io.ktor.http.HttpStatusCode
import io.ktor.serialization.kotlinx.json.*
import io.ktor.server.application.*
import io.ktor.server.plugins.contentnegotiation.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.serialization.Serializable

@Serializable
data class HealthResponse(
    val status: String,
    val timestamp: Long
)

fun Application.configureRouting() {
    routing {
        get("/health") {
            call.respond(
                status = HttpStatusCode.OK,
                message = HealthResponse(
                    status = "OK",
                    timestamp = System.currentTimeMillis()
                )
            )
        }

        get("/") {
            call.respondText("Hello World!")
        }
    }
}
