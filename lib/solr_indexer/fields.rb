module SolrIndexer
  class LiteralField
    attr_reader :name, :value

    def initialize(name, value)
      @name = name
      @value = value
    end
  end
end

class SimpleField
  attr_reader :source, :destination

  def initialize(source, destination)
    @source = source
    @destination = [destination].flatten
  end
end

class BundleField
  attr_reader :source, :destination, :name

  def initialize(source, destination, name)
    @source = source
    @destination = [destination].flatten
    @name = name
  end
end

class PrefixedField
  attr_reader :source, :destination, :prefix

  def initialize(source, destination, prefix)
    @source = source
    @destination = [destination].flatten
    @prefix = prefix
  end
end
