module TransactionInterceptor
  def transaction *methods
    methods.each do |method|
      original_method = instance_method method
      define_method method do |*args, **kwargs, &blk|
        ActiveRecord::Base.transaction do
          original_method.bind_call(self, *args, **kwargs, &blk)
        end
      end
    end
  end

  def apply_query_cache *methods
    methods.each do |method|
      original_method = instance_method method
      define_method method do |*args, **kwargs, &blk|
        ActiveRecord::Base.cache do
          original_method.bind_call(self, *args, **kwargs, &blk)
        end
      end
    end
  end

  def cache_and_transaction *methods
    transaction(*methods)
    apply_query_cache(*methods)
  end
end
