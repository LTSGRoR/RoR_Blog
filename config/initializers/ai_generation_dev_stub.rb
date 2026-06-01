if Rails.env.development? && ENV["AI_USE_DEV_STUB"] == "true"
  begin
    if defined?(AiGeneration::Service)
      service_klass = AiGeneration::Service
      unless service_klass.instance_methods.include?(:embed)
        service_klass.class_eval do
          def embed(text:)
            # return a zero vector matching the expected dimension
            dim = if defined?(AiGeneration::Service::TARGET_EMBEDDING_DIM)
              AiGeneration::Service::TARGET_EMBEDDING_DIM
            else
              ENV.fetch("AI_EMBEDDING_DIM", "1536").to_i
            end
            Array.new(dim, 0.0)
          end
        end
      end

      unless service_klass.instance_methods.include?(:generate)
        service_klass.class_eval do
          def generate(prompt:, user:, context: {})
            { result: "DEV GENERATED: " + prompt.to_s.truncate(400), provider: "dev", meta: {} }
          end
        end
      end
    else
      module AiGeneration
        class Service
          def embed(text:)
            dim = if defined?(AiGeneration::Service::TARGET_EMBEDDING_DIM)
              AiGeneration::Service::TARGET_EMBEDDING_DIM
            else
              ENV.fetch("AI_EMBEDDING_DIM", "1536").to_i
            end
            Array.new(dim, 0.0)
          end

          def generate(prompt:, user:, context: {})
            { result: "DEV GENERATED: " + prompt.to_s.truncate(400), provider: "dev", meta: {} }
          end
        end
      end
    end
  rescue StandardError => e
    Rails.logger.warn "ai_generation_dev_stub load error: #{e.class} - #{e.message}" if defined?(Rails)
  end
end
