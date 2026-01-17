package com.cleaning.plugins

import com.cleaning.routes.reportRoutes
import io.ktor.server.application.*
import io.ktor.server.response.*
import io.ktor.server.routing.*


fun Application.configureRouting() {
    routing {
        reportRoutes()
        get("/") {
            call.respondText("Hello World!")
        }
    }
}
