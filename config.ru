require './app'
require './middlewares/chat'

use Chat::Server
run Chat::App
