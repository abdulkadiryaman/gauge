require_relative 'messages.pb'
require_relative 'executor'
require 'tempfile'


class ExecuteStepProcessor

  def process(message)
    step_text = message.executeStepRequest.parsedStepText
    arguments = message.executeStepRequest.args
    args = create_arg_values arguments
    begin
      execute_step step_text, args
    rescue Exception => e
      return handle_step_failure message, e
    end
    handle_step_pass message
  end

  def create_arg_values arguments
    args = []
    arguments.each do |argument|
      if (argument.type = "table")
        args.push argument.table
      else
        args.push argument.value
      end
    end
    return args
  end

  def handle_step_pass(message)
    execution_status_response = Main::ExecutionStatusResponse.new(:executionStatus => Main::ExecutionStatus.new(:passed => true))
    Main::Message.new(:messageType => Main::Message::MessageType::ExecutionStatusResponse, :messageId => message.messageId, :executionStatusResponse => execution_status_response)
  end

  def handle_step_failure(message, exception)
    execution_status_response = Main::ExecutionStatusResponse.new(:executionStatus => Main::ExecutionStatus.new(:passed => false,
                                                                                                                :recoverableError => false,
                                                                                                                :errorMessage => exception.message,
                                                                                                                :stackTrace => exception.backtrace.join("\n"),
                                                                                                                :screenShot => screenshot_bytes))
    Main::Message.new(:messageType => Main::Message::MessageType::ExecutionStatusResponse, :messageId => message.messageId, :executionStatusResponse => execution_status_response)
  end

  def screenshot_bytes
    file = File.open("#{Dir.tmpdir}/screenshot.png", "w+")
    `screencapture #{file.path}`
    file_content = file.read
    File.delete file
    return file_content
  end
end

class ExecutionStartProcessor
  def process(message)
    execution_status_response = Main::ExecutionStatusResponse.new(:executionStatus => Main::ExecutionStatus.new(:passed => true))
    Main::Message.new(:messageType => Main::Message::MessageType::ExecutionStatusResponse, :messageId => message.messageId, :executionStatusResponse => execution_status_response)
  end
end

class StepValidationProcessor
  def process(message)
    step_validate_request = message.stepValidateRequest
    step_validate_response = Main::StepValidateResponse.new(:isValid => is_valid_step(step_validate_request.stepText))
    Main::Message.new(:messageType => Main::Message::MessageType::StepValidateResponse, :messageId => message.messageId, :stepValidateResponse => step_validate_response)
  end
end

class StepNamesProcessor
  def process(message)
    Main::StepNamesResponse.new(:steps => $steps_map.keys)
    Main::Message.new(:messageType => Main::Message::MessageType::StepNamesResponse, :messageId => message.messageId, :stepNamesResponse => step_names_response)
  end
end

class KillProcessProcessor
  def process(message)
    return message
  end
end

class MessageProcessor
  @processors = Hash.new
  @processors[Main::Message::MessageType::StepValidateRequest] = StepValidationProcessor.new
  @processors[Main::Message::MessageType::ExecutionStarting] = ExecutionStartProcessor.new
  @processors[Main::Message::MessageType::SpecExecutionStarting] = ExecutionStartProcessor.new
  @processors[Main::Message::MessageType::SpecExecutionEnding] = ExecutionStartProcessor.new
  @processors[Main::Message::MessageType::ScenarioExecutionStarting] = ExecutionStartProcessor.new
  @processors[Main::Message::MessageType::ScenarioExecutionEnding] = ExecutionStartProcessor.new
  @processors[Main::Message::MessageType::StepExecutionStarting] = ExecutionStartProcessor.new
  @processors[Main::Message::MessageType::StepExecutionEnding] = ExecutionStartProcessor.new
  @processors[Main::Message::MessageType::ExecuteStep] = ExecuteStepProcessor.new
  @processors[Main::Message::MessageType::ExecutionEnding] = ExecutionStartProcessor.new
  @processors[Main::Message::MessageType::StepNamesRequest] = StepNamesProcessor.new
  @processors[Main::Message::MessageType::KillProcessRequest] = KillProcessProcessor.new

  def self.is_valid_message(message)
    return @processors.has_key? message.messageType
  end

  def self.process_message(message)
    @processors[message.messageType].process message
  end

end


