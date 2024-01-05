# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `dry-initializer` gem.
# Please instead update this file by running `bin/tapioca gem dry-initializer`.

# Namespace for gems in a dry-rb community
#
# source://dry-initializer//lib/dry/initializer.rb#6
module Dry
  class << self
    # source://dry-configurable/1.1.0/lib/dry/configurable.rb#11
    def Configurable(**options); end

    # source://dry-core/1.0.1/lib/dry/core.rb#52
    def Equalizer(*keys, **options); end

    # source://dry-types/1.7.1/lib/dry/types.rb#253
    def Types(*namespaces, default: T.unsafe(nil), **aliases); end
  end
end

# DSL for declaring params and options of class initializers
#
# source://dry-initializer//lib/dry/initializer.rb#10
module Dry::Initializer
  extend ::Dry::Initializer::DSL

  # Gem-related configuration
  #
  # @return [Dry::Initializer::Config]
  #
  # source://dry-initializer//lib/dry/initializer.rb#24
  def dry_initializer; end

  # Adds or redefines an option of [#dry_initializer]
  #
  # @option opts
  # @option opts
  # @option opts
  # @option opts
  # @param name [Symbol]
  # @param type [#call, nil] (nil)
  # @param opts [Hash] a customizable set of options
  # @return [self] itself
  # @yield block with nested definition
  #
  # source://dry-initializer//lib/dry/initializer.rb#47
  def option(name, type = T.unsafe(nil), **opts, &block); end

  # Adds or redefines a parameter of [#dry_initializer]
  #
  # @option opts
  # @option opts
  # @option opts
  # @option opts
  # @param name [Symbol]
  # @param type [#call, nil] (nil)
  # @param opts [Hash] a customizable set of options
  # @return [self] itself
  # @yield block with nested definition
  #
  # source://dry-initializer//lib/dry/initializer.rb#37
  def param(name, type = T.unsafe(nil), **opts, &block); end

  private

  # source://dry-initializer//lib/dry/initializer.rb#54
  def inherited(klass); end
end

# @private
#
# source://dry-initializer//lib/dry/initializer/builders.rb#6
module Dry::Initializer::Builders; end

# @private
#
# source://dry-initializer//lib/dry/initializer/builders/attribute.rb#7
class Dry::Initializer::Builders::Attribute
  # @return [Attribute] a new instance of Attribute
  #
  # source://dry-initializer//lib/dry/initializer/builders/attribute.rb#18
  def initialize(definition); end

  # source://dry-initializer//lib/dry/initializer/builders/attribute.rb#12
  def call; end

  private

  # source://dry-initializer//lib/dry/initializer/builders/attribute.rb#83
  def assignment_line; end

  # source://dry-initializer//lib/dry/initializer/builders/attribute.rb#71
  def coercion_line; end

  # source://dry-initializer//lib/dry/initializer/builders/attribute.rb#65
  def default_line; end

  # source://dry-initializer//lib/dry/initializer/builders/attribute.rb#59
  def definition_line; end

  # source://dry-initializer//lib/dry/initializer/builders/attribute.rb#33
  def lines; end

  # source://dry-initializer//lib/dry/initializer/builders/attribute.rb#50
  def optional_reader; end

  # source://dry-initializer//lib/dry/initializer/builders/attribute.rb#44
  def reader_line; end

  # source://dry-initializer//lib/dry/initializer/builders/attribute.rb#54
  def required_reader; end

  class << self
    # source://dry-initializer//lib/dry/initializer/builders/attribute.rb#8
    def [](definition); end
  end
end

# @private
#
# source://dry-initializer//lib/dry/initializer/builders/initializer.rb#7
class Dry::Initializer::Builders::Initializer
  # @return [Initializer] a new instance of Initializer
  #
  # source://dry-initializer//lib/dry/initializer/builders/initializer.rb#21
  def initialize(config); end

  # source://dry-initializer//lib/dry/initializer/builders/initializer.rb#15
  def call; end

  private

  # source://dry-initializer//lib/dry/initializer/builders/initializer.rb#41
  def define_line; end

  # source://dry-initializer//lib/dry/initializer/builders/initializer.rb#53
  def end_line; end

  # source://dry-initializer//lib/dry/initializer/builders/initializer.rb#26
  def lines; end

  # source://dry-initializer//lib/dry/initializer/builders/initializer.rb#49
  def options_lines; end

  # source://dry-initializer//lib/dry/initializer/builders/initializer.rb#45
  def params_lines; end

  # source://dry-initializer//lib/dry/initializer/builders/initializer.rb#36
  def undef_line; end

  class << self
    # source://dry-initializer//lib/dry/initializer/builders/initializer.rb#11
    def [](config); end
  end
end

# @private
#
# source://dry-initializer//lib/dry/initializer/builders/reader.rb#7
class Dry::Initializer::Builders::Reader
  # @return [Reader] a new instance of Reader
  #
  # source://dry-initializer//lib/dry/initializer/builders/reader.rb#18
  def initialize(definition); end

  # source://dry-initializer//lib/dry/initializer/builders/reader.rb#12
  def call; end

  private

  # source://dry-initializer//lib/dry/initializer/builders/reader.rb#35
  def attribute_line; end

  # source://dry-initializer//lib/dry/initializer/builders/reader.rb#25
  def lines; end

  # source://dry-initializer//lib/dry/initializer/builders/reader.rb#41
  def method_lines; end

  # source://dry-initializer//lib/dry/initializer/builders/reader.rb#52
  def type_line; end

  # source://dry-initializer//lib/dry/initializer/builders/reader.rb#29
  def undef_line; end

  class << self
    # source://dry-initializer//lib/dry/initializer/builders/reader.rb#8
    def [](definition); end
  end
end

# @private
#
# source://dry-initializer//lib/dry/initializer/builders/signature.rb#7
class Dry::Initializer::Builders::Signature
  # @return [Signature] a new instance of Signature
  #
  # source://dry-initializer//lib/dry/initializer/builders/signature.rb#18
  def initialize(config); end

  # source://dry-initializer//lib/dry/initializer/builders/signature.rb#12
  def call; end

  private

  # source://dry-initializer//lib/dry/initializer/builders/signature.rb#28
  def optional_params; end

  # source://dry-initializer//lib/dry/initializer/builders/signature.rb#32
  def options; end

  # source://dry-initializer//lib/dry/initializer/builders/signature.rb#24
  def required_params; end

  class << self
    # source://dry-initializer//lib/dry/initializer/builders/signature.rb#8
    def [](config); end
  end
end

# Gem-related configuration of some class
#
# source://dry-initializer//lib/dry/initializer/config.rb#8
class Dry::Initializer::Config
  # @return [Config] a new instance of Config
  #
  # source://dry-initializer//lib/dry/initializer/config.rb#131
  def initialize(extended_class = T.unsafe(nil), null: T.unsafe(nil)); end

  # The hash of assigned attributes for an instance of the [#extended_class]
  #
  # @param instance [Dry::Initializer::Instance]
  # @return [Hash<Symbol, Object>]
  #
  # source://dry-initializer//lib/dry/initializer/config.rb#93
  def attributes(instance); end

  # List of configs of all subclasses of the [#extended_class]
  #
  # @return [Array<Dry::Initializer::Config>]
  #
  # source://dry-initializer//lib/dry/initializer/config.rb#39
  def children; end

  # Code of the `#__initialize__` method
  #
  # @return [String]
  #
  # source://dry-initializer//lib/dry/initializer/config.rb#103
  def code; end

  # @return [Hash<Symbol, Dry::Initializer::Definition>] hash of attribute definitions with their source names
  #
  # source://dry-initializer//lib/dry/initializer/config.rb#22
  def definitions; end

  # @return [Hash<Symbol, Dry::Initializer::Definition>] hash of attribute definitions with their source names
  #
  # source://dry-initializer//lib/dry/initializer/config.rb#22
  def extended_class; end

  # Finalizes config
  #
  # @return [self]
  #
  # source://dry-initializer//lib/dry/initializer/config.rb#109
  def finalize; end

  # Human-readable representation of configured params and options
  #
  # @return [String]
  #
  # source://dry-initializer//lib/dry/initializer/config.rb#119
  def inch; end

  # @return [Module] reference to the module to be included into class
  #
  # source://dry-initializer//lib/dry/initializer/config.rb#26
  def mixin; end

  # @return [Hash<Symbol, Dry::Initializer::Definition>] hash of attribute definitions with their source names
  #
  # source://dry-initializer//lib/dry/initializer/config.rb#22
  def null; end

  # Adds or redefines an option of [#dry_initializer]
  #
  # @option opts
  # @option opts
  # @option opts
  # @option opts
  # @param name [Symbol]
  # @param type [#call, nil] (nil)
  # @param opts [Hash] a customizable set of options
  # @return [self] itself
  #
  # source://dry-initializer//lib/dry/initializer/config.rb#73
  def option(name, type = T.unsafe(nil), **opts, &block); end

  # List of definitions for initializer options
  #
  # @return [Array<Dry::Initializer::Definition>]
  #
  # source://dry-initializer//lib/dry/initializer/config.rb#51
  def options; end

  # Adds or redefines a parameter
  #
  # @option opts
  # @option opts
  # @option opts
  # @option opts
  # @param name [Symbol]
  # @param type [#call, nil] (nil)
  # @param opts [Hash] a customizable set of options
  # @return [self] itself
  #
  # source://dry-initializer//lib/dry/initializer/config.rb#63
  def param(name, type = T.unsafe(nil), **opts, &block); end

  # List of definitions for initializer params
  #
  # @return [Array<Dry::Initializer::Definition>]
  #
  # source://dry-initializer//lib/dry/initializer/config.rb#45
  def params; end

  # @return [Hash<Symbol, Dry::Initializer::Definition>] hash of attribute definitions with their source names
  #
  # source://dry-initializer//lib/dry/initializer/config.rb#22
  def parent; end

  # The hash of public attributes for an instance of the [#extended_class]
  #
  # @param instance [Dry::Initializer::Instance]
  # @return [Hash<Symbol, Object>]
  #
  # source://dry-initializer//lib/dry/initializer/config.rb#80
  def public_attributes(instance); end

  private

  # source://dry-initializer//lib/dry/initializer/config.rb#140
  def add_definition(option, name, type, block, **opts); end

  # source://dry-initializer//lib/dry/initializer/config.rb#174
  def check_order_of_params; end

  # @raise [SyntaxError]
  #
  # source://dry-initializer//lib/dry/initializer/config.rb#165
  def check_type(previous, current); end

  # source://dry-initializer//lib/dry/initializer/config.rb#158
  def final_definitions; end
end

# Module-level DSL
#
# source://dry-initializer//lib/dry/initializer/dsl.rb#6
module Dry::Initializer::DSL
  # Returns a version of the module with custom settings
  #
  # @option settings
  # @param settings [Hash] a customizable set of options
  # @return [Dry::Initializer]
  #
  # source://dry-initializer//lib/dry/initializer/dsl.rb#15
  def [](undefined: T.unsafe(nil), **_arg1); end

  # Returns mixin module to be included to target class by hand
  #
  # @return [Module]
  # @yield proc defining params and options
  #
  # source://dry-initializer//lib/dry/initializer/dsl.rb#27
  def define(procedure = T.unsafe(nil), &block); end

  # Setting for null (undefined value)
  #
  # @return [nil, Dry::Initializer::UNDEFINED]
  #
  # source://dry-initializer//lib/dry/initializer/dsl.rb#9
  def null; end

  private

  # source://dry-initializer//lib/dry/initializer/dsl.rb#36
  def extended(klass); end

  class << self
    private

    # @private
    #
    # source://dry-initializer//lib/dry/initializer/dsl.rb#45
    def extended(mod); end
  end
end

# Base class for parameter or option definitions
# Defines methods to add corresponding reader to the class,
# and build value of instance attribute.
#
# @abstract
# @private
#
# source://dry-initializer//lib/dry/initializer/definition.rb#13
class Dry::Initializer::Definition
  # @return [Definition] a new instance of Definition
  #
  # source://dry-initializer//lib/dry/initializer/definition.rb#55
  def initialize(**options); end

  # source://dry-initializer//lib/dry/initializer/definition.rb#36
  def ==(other); end

  # source://dry-initializer//lib/dry/initializer/definition.rb#40
  def code; end

  # Returns the value of attribute default.
  #
  # source://dry-initializer//lib/dry/initializer/definition.rb#14
  def default; end

  # Returns the value of attribute desc.
  #
  # source://dry-initializer//lib/dry/initializer/definition.rb#14
  def desc; end

  # source://dry-initializer//lib/dry/initializer/definition.rb#44
  def inch; end

  # source://dry-initializer//lib/dry/initializer/definition.rb#29
  def inspect; end

  # Returns the value of attribute ivar.
  #
  # source://dry-initializer//lib/dry/initializer/definition.rb#14
  def ivar; end

  # source://dry-initializer//lib/dry/initializer/definition.rb#29
  def name; end

  # Returns the value of attribute null.
  #
  # source://dry-initializer//lib/dry/initializer/definition.rb#14
  def null; end

  # Returns the value of attribute option.
  #
  # source://dry-initializer//lib/dry/initializer/definition.rb#14
  def option; end

  # Returns the value of attribute optional.
  #
  # source://dry-initializer//lib/dry/initializer/definition.rb#14
  def optional; end

  # source://dry-initializer//lib/dry/initializer/definition.rb#18
  def options; end

  # Returns the value of attribute reader.
  #
  # source://dry-initializer//lib/dry/initializer/definition.rb#14
  def reader; end

  # Returns the value of attribute source.
  #
  # source://dry-initializer//lib/dry/initializer/definition.rb#14
  def source; end

  # Returns the value of attribute target.
  #
  # source://dry-initializer//lib/dry/initializer/definition.rb#14
  def target; end

  # source://dry-initializer//lib/dry/initializer/definition.rb#29
  def to_s; end

  # source://dry-initializer//lib/dry/initializer/definition.rb#29
  def to_str; end

  # Returns the value of attribute type.
  #
  # source://dry-initializer//lib/dry/initializer/definition.rb#14
  def type; end
end

# source://dry-initializer//lib/dry/initializer/dispatchers.rb#66
module Dry::Initializer::Dispatchers
  extend ::Dry::Initializer::Dispatchers

  # Registers a new dispatcher
  #
  # @param dispatcher [#call]
  # @return [self] itself
  #
  # source://dry-initializer//lib/dry/initializer/dispatchers.rb#79
  def <<(dispatcher); end

  # Normalizes the source set of options
  #
  # @param options [Hash<Symbol, Object>]
  # @return [Hash<Symbol, Objct>] normalized set of options
  #
  # source://dry-initializer//lib/dry/initializer/dispatchers.rb#90
  def call(**options); end

  # @return [Object]
  #
  # source://dry-initializer//lib/dry/initializer/dispatchers.rb#71
  def null; end

  # @return [Object]
  #
  # source://dry-initializer//lib/dry/initializer/dispatchers.rb#71
  def null=(_arg0); end

  private

  # source://dry-initializer//lib/dry/initializer/dispatchers.rb#108
  def pipeline; end
end

# source://dry-initializer//lib/dry/initializer/dispatchers/build_nested_type.rb#14
module Dry::Initializer::Dispatchers::BuildNestedType
  extend ::Dry::Initializer::Dispatchers::BuildNestedType

  # source://dry-initializer//lib/dry/initializer/dispatchers/build_nested_type.rb#18
  def call(parent:, source:, target:, type: T.unsafe(nil), block: T.unsafe(nil), **options); end

  private

  # source://dry-initializer//lib/dry/initializer/dispatchers/build_nested_type.rb#48
  def build_nested_type(parent, name, block); end

  # source://dry-initializer//lib/dry/initializer/dispatchers/build_nested_type.rb#59
  def build_struct(klass_name, block); end

  # @raise [ArgumentError]
  #
  # source://dry-initializer//lib/dry/initializer/dispatchers/build_nested_type.rb#28
  def check_certainty!(source, type, block); end

  # @raise [ArgumentError]
  #
  # source://dry-initializer//lib/dry/initializer/dispatchers/build_nested_type.rb#38
  def check_name!(name, block); end

  # source://dry-initializer//lib/dry/initializer/dispatchers/build_nested_type.rb#55
  def full_name(parent, name); end
end

# source://dry-initializer//lib/dry/initializer/dispatchers/check_type.rb#8
module Dry::Initializer::Dispatchers::CheckType
  extend ::Dry::Initializer::Dispatchers::CheckType

  # source://dry-initializer//lib/dry/initializer/dispatchers/check_type.rb#11
  def call(source:, type: T.unsafe(nil), wrap: T.unsafe(nil), **options); end

  private

  # @raise [ArgumentError]
  #
  # source://dry-initializer//lib/dry/initializer/dispatchers/check_type.rb#28
  def check_arity!(_source, type, wrap); end

  # @raise [ArgumentError]
  #
  # source://dry-initializer//lib/dry/initializer/dispatchers/check_type.rb#20
  def check_if_callable!(source, type); end
end

# source://dry-initializer//lib/dry/initializer/dispatchers/prepare_default.rb#10
module Dry::Initializer::Dispatchers::PrepareDefault
  extend ::Dry::Initializer::Dispatchers::PrepareDefault

  # source://dry-initializer//lib/dry/initializer/dispatchers/prepare_default.rb#13
  def call(default: T.unsafe(nil), optional: T.unsafe(nil), **options); end

  private

  # source://dry-initializer//lib/dry/initializer/dispatchers/prepare_default.rb#22
  def callable!(default); end

  # source://dry-initializer//lib/dry/initializer/dispatchers/prepare_default.rb#30
  def check_arity!(default); end

  # @raise [TypeError]
  #
  # source://dry-initializer//lib/dry/initializer/dispatchers/prepare_default.rb#39
  def invalid!(default); end
end

# source://dry-initializer//lib/dry/initializer/dispatchers/prepare_ivar.rb#8
module Dry::Initializer::Dispatchers::PrepareIvar
  private

  # source://dry-initializer//lib/dry/initializer/dispatchers/prepare_ivar.rb#11
  def call(target:, **options); end

  class << self
    # source://dry-initializer//lib/dry/initializer/dispatchers/prepare_ivar.rb#11
    def call(target:, **options); end
  end
end

# source://dry-initializer//lib/dry/initializer/dispatchers/prepare_optional.rb#8
module Dry::Initializer::Dispatchers::PrepareOptional
  private

  # source://dry-initializer//lib/dry/initializer/dispatchers/prepare_optional.rb#11
  def call(optional: T.unsafe(nil), default: T.unsafe(nil), required: T.unsafe(nil), **options); end

  class << self
    # source://dry-initializer//lib/dry/initializer/dispatchers/prepare_optional.rb#11
    def call(optional: T.unsafe(nil), default: T.unsafe(nil), required: T.unsafe(nil), **options); end
  end
end

# source://dry-initializer//lib/dry/initializer/dispatchers/prepare_reader.rb#8
module Dry::Initializer::Dispatchers::PrepareReader
  extend ::Dry::Initializer::Dispatchers::PrepareReader

  # source://dry-initializer//lib/dry/initializer/dispatchers/prepare_reader.rb#11
  def call(target: T.unsafe(nil), reader: T.unsafe(nil), **options); end

  private

  # @raise [ArgumentError]
  #
  # source://dry-initializer//lib/dry/initializer/dispatchers/prepare_reader.rb#24
  def invalid_reader!(target, _reader); end
end

# source://dry-initializer//lib/dry/initializer/dispatchers/prepare_source.rb#26
module Dry::Initializer::Dispatchers::PrepareSource
  private

  # source://dry-initializer//lib/dry/initializer/dispatchers/prepare_source.rb#29
  def call(source:, **options); end

  class << self
    # source://dry-initializer//lib/dry/initializer/dispatchers/prepare_source.rb#29
    def call(source:, **options); end
  end
end

# source://dry-initializer//lib/dry/initializer/dispatchers/prepare_target.rb#11
module Dry::Initializer::Dispatchers::PrepareTarget
  extend ::Dry::Initializer::Dispatchers::PrepareTarget

  # source://dry-initializer//lib/dry/initializer/dispatchers/prepare_target.rb#23
  def call(source:, target: T.unsafe(nil), as: T.unsafe(nil), **options); end

  private

  # @raise [ArgumentError]
  #
  # source://dry-initializer//lib/dry/initializer/dispatchers/prepare_target.rb#42
  def check_reserved_names!(target); end

  # @raise [ArgumentError]
  #
  # source://dry-initializer//lib/dry/initializer/dispatchers/prepare_target.rb#35
  def check_ruby_name!(target); end
end

# List of variable names reserved by the gem
#
# source://dry-initializer//lib/dry/initializer/dispatchers/prepare_target.rb#15
Dry::Initializer::Dispatchers::PrepareTarget::RESERVED = T.let(T.unsafe(nil), Array)

# source://dry-initializer//lib/dry/initializer/dispatchers/unwrap_type.rb#12
module Dry::Initializer::Dispatchers::UnwrapType
  extend ::Dry::Initializer::Dispatchers::UnwrapType

  # source://dry-initializer//lib/dry/initializer/dispatchers/unwrap_type.rb#15
  def call(type: T.unsafe(nil), wrap: T.unsafe(nil), **options); end

  private

  # source://dry-initializer//lib/dry/initializer/dispatchers/unwrap_type.rb#23
  def unwrap(type, count); end
end

# source://dry-initializer//lib/dry/initializer/dispatchers/wrap_type.rb#8
module Dry::Initializer::Dispatchers::WrapType
  extend ::Dry::Initializer::Dispatchers::WrapType

  # source://dry-initializer//lib/dry/initializer/dispatchers/wrap_type.rb#11
  def call(type: T.unsafe(nil), wrap: T.unsafe(nil), **options); end

  private

  # source://dry-initializer//lib/dry/initializer/dispatchers/wrap_type.rb#23
  def wrap_value(value, count, type); end

  # source://dry-initializer//lib/dry/initializer/dispatchers/wrap_type.rb#17
  def wrapped_type(type, count); end
end

# @private
#
# source://dry-initializer//lib/dry/initializer/mixin.rb#6
module Dry::Initializer::Mixin
  include ::Dry::Initializer
  extend ::Dry::Initializer::DSL

  class << self
    # @deprecated
    #
    # source://dry-initializer//lib/dry/initializer/mixin.rb#10
    def extended(klass); end
  end
end

# @private
#
# source://dry-initializer//lib/dry/initializer/mixin/local.rb#7
module Dry::Initializer::Mixin::Local
  # source://dry-initializer//lib/dry/initializer/mixin/local.rb#10
  def inspect; end

  # Returns the value of attribute klass.
  #
  # source://dry-initializer//lib/dry/initializer/mixin/local.rb#8
  def klass; end

  # source://dry-initializer//lib/dry/initializer/mixin/local.rb#10
  def to_s; end

  # source://dry-initializer//lib/dry/initializer/mixin/local.rb#10
  def to_str; end

  private

  # source://dry-initializer//lib/dry/initializer/mixin/local.rb#18
  def included(klass); end
end

# @private
#
# source://dry-initializer//lib/dry/initializer/mixin/root.rb#7
module Dry::Initializer::Mixin::Root
  # source://dry-initializer//lib/dry/initializer/mixin/root.rb#10
  def initialize(*_arg0, **_arg1, &_arg2); end
end

# source://dry-initializer//lib/dry/initializer/struct.rb#7
class Dry::Initializer::Struct
  include ::Dry::Initializer::Mixin::Root
  extend ::Dry::Initializer

  # Represents event data as a nested hash with deeply stringified keys
  #
  # @return [Hash<String, ...>]
  #
  # source://dry-initializer//lib/dry/initializer/struct.rb#23
  def to_h; end

  private

  # source://dry-initializer//lib/dry/initializer/struct.rb#33
  def __hashify(value); end

  class << self
    # source://dry-initializer//lib/dry/initializer/struct.rb#13
    def call(options); end

    # source://dry-initializer//lib/dry/initializer/struct.rb#13
    def new(options); end
  end
end

# source://dry-initializer//lib/dry/initializer/undefined.rb#5
module Dry::Initializer::UNDEFINED; end
