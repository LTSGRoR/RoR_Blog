# Register the pgvector type with ActiveRecord so `vector` columns are recognized
begin
  require "pgvector"

  ActiveSupport.on_load(:active_record) do
    if defined?(ActiveRecord::Type) && defined?(Pgvector::ActiveRecord::Vector)
      ActiveRecord::Type.register(:vector, Pgvector::ActiveRecord::Vector.new)
    end
  end
rescue LoadError => e
  Rails.logger.warn("pgvector gem not available: ") if defined?(Rails)
end
