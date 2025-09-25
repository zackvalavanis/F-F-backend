class OpenaiService
  def initialize
    @client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
  end

  def chat_system_user(system_msg, user_msg, model: "gpt-4", temperature: 0.2, max_tokens: 800)
    response = @client.chat(
      parameters: {
        model: model,
        messages: [
          { role: "system", content: system_msg },
          { role: "user", content: user_msg }
        ],
        temperature: temperature,
        max_tokens: max_tokens
      }
    )
    response.dig("choices", 0, "message", "content")
  end
end
