require 'socket'
require 'protocol_buffers'

require_relative 'messages.pb'
require_relative 'executor'
require_relative 'message-processor'

HOST_NAME = 'localhost'
PORT_ENV = "GAUGE_INTERNAL_PORT"
DEFAULT_IMPLEMENTATIONS_DIR_PATH = "#{Dir.pwd}/step_implementations"

def dispatch_messages(socket)
  while (!socket.eof?)
    len = message_length(socket)
    data = socket.read len
    message = Main::Message.parse(data)
    handle_message(socket, message)
    if (message.messageType == Main::Message::MessageType::KillProcessRequest)
      socket.close
      return
    end
  end
end


def handle_message(socket, message)
  if (!MessageProcessor.is_valid_message(message))
    puts "Invalid message received : #{message}"
  else
    response = MessageProcessor.process_message message
    write_message(socket, response)
  end
end

def message_length(socket)
  ProtocolBuffers::Varint.decode socket
end

def write_message(socket, message)
  serialized_message = message.to_s
  size = serialized_message.bytesize
  ProtocolBuffers::Varint.encode(socket, size)
  socket.write serialized_message
end

def port()
  port = ENV[PORT_ENV]
  if (port.nil?)
    raise RuntimeError, "Could not find Env variable :#{PORT_ENV}"
  end
  return port
end

STDOUT.sync = true
socket = TCPSocket.open(HOST_NAME, port())
load_steps(DEFAULT_IMPLEMENTATIONS_DIR_PATH)
dispatch_messages(socket)

