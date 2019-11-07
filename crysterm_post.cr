# User must define custom events before loading this file, as it will load event_emitter, at which point the macros will run and any events added later will be ignored.

require "./events_widgets"
require "./event_emitter"

require "./stream"
require "./keys"

require "./program"
require "./gpmclient"

require "./widgets/node"
require "./widgets/screen"
require "./widgets/element"
