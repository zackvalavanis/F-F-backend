require 'openai'
require 'open-uri'

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

  def generate_image(prompt, size: "512x512")
    Rails.logger.info("IMAGE PROMPT: #{prompt.inspect}")
    
    response = @client.images.generate(
      parameters: {
        model: "gpt-image-1",
        prompt: prompt,
        size: size
      }
    )
    
    Rails.logger.info("IMAGE RESPONSE: #{response.inspect}")
    response.dig("data", 0, "url")
  rescue Faraday::BadRequestError, Faraday::ForbiddenError => e
    Rails.logger.error("Image generation failed: #{e.response_body}")
    nil
  end
  
end
