require 'concurrent'

module Hanami
  # IoC Container
  #
  # The implementation is thread-safe
  #
  # @since x.x.x
  # @api private
  module Container
    # Available components
    #
    # @since x.x.x
    # @api private
    @_components = Concurrent::Hash.new

    # Resolved components
    #
    # @since x.x.x
    # @api private
    @_resolved   = Concurrent::Map.new

    # Register a component
    #
    # @param name [String] the unique component name
    # @param blk [Proc] the logic of the component
    #
    # @since x.x.x
    # @api private
    #
    # @see Hanami::Container::Component
    def self.register(name, &blk)
      @_components[name] = Component.new(name, &blk)
    end

    # Return a registered component
    #
    # @param name [String] the name of the component
    #
    # @raise [ArgumentError] if the component is unknown
    #
    # @since x.x.x
    # @api private
    def self.component(name)
      @_components.fetch(name) do
        raise ArgumentError.new("Component not found: `#{name}'.\nAvailable components are: #{@_components.keys.join(', ')}")
      end
    end

    # Mark a component as resolved by providing a value or a block.
    # In the latter case, the returning value of the block is associated with
    # the component.
    #
    # @param name [String] the name of the component to mark as resolved
    # @param value [Object] the optional value of the component
    # @param blk [Proc] the optional block which returning value is associated with the component.
    #
    # @since x.x.x
    # @api private
    def self.resolved(name, value = nil, &blk)
      if block_given?
        @_resolved.fetch_or_store(name, &blk)
      else
        @_resolved.compute_if_absent(name) { value }
      end
    end

    # Ask to resolve a component.
    #
    # This is used as dependency mechanism.
    # For instance `model` component depends on `model.configuration`. Before to
    # resolve `model`, `Container` uses this method to resolve that dependency first.
    #
    # @param names [String,Array<String>] one or more components to be resolved
    #
    # @since x.x.x
    # @api private
    def self.resolve(*names)
      Array(names).flatten.each do |name|
        @_resolved.fetch_or_store(name) do
          component = @_components.fetch(name)
          component.call(Hanami.configuration)
        end
      end
    end

    # Return the value of an already resolved component.
    #
    # @param name [String] the component name
    #
    # @raise [ArgumentError] if the component is unknown or not resolved yet.
    #
    # @since x.x.x
    # @api private
    def self.[](name)
      @_resolved.fetch(name) do
        raise ArgumentError.new("Component not resolved: `#{name}'.\nResolved components are: #{@_resolved.keys.join(', ')}")
      end
    end

    # Release all the resolved components.
    # This is used for code reloading.
    #
    # NOTE: this MUST NOT be used unless you know what you're doing.
    #
    # @since x.x.x
    # @api private
    def self.release
      @_resolved.clear
    end

    require 'hanami/container/component'
  end
end
