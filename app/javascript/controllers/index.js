// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"

// Manually import and register the reactions controller
import ReactionsController from "controllers/reactions_controller"
application.register("reactions", ReactionsController)

// Load all other controllers
eagerLoadControllersFrom("controllers", application)



