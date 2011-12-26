module AST

class SemanticError < StandardError ; end

class Node
  attr_reader :name
  attr_reader :node_type

  # symbol tables
  attr_accessor :vars
  attr_accessor :types
  attr_accessor :procs
  
  @@indent = 0

  def initialize(name, node_type = nil)
    @name = name
    @node_type = node_type
  end
  
  def to_s(child_nodes = nil)
    if !child_nodes.nil?
      s = "(" + @name
      for child in child_nodes
        s = s + " " + child.to_s
      end
      
      s += close_node
    else
      @name.to_s
    end
  end

  def indent(i = 0)
    s = ""
    for i in 0..(@@indent * 2 + i - 1)
      s += " "
    end
    s
  end
    
  def close_node(is_indented = false)
    s = ""
    if is_indented
      s += indent
    end
    s += ")"
  end
  
  def walk_ast(fn)
    fn.call(self)
  end
end

class TopNode < Node
  attr_reader :proc_nodes
  attr_reader :stm_nodes

  def initialize(proc_nodes, stm_nodes)
    super("program")
    @proc_nodes = proc_nodes
    @stm_nodes = stm_nodes
  end
  
  def to_s
    s = "(\n"
    @@indent += 1
    s += indent + @proc_nodes.to_s + "\n"
    s += indent + @stm_nodes.to_s + "\n"
    @@indent -= 1
    s = s + indent + ")"
    s
  end
  
  def walk_ast(fn)
    super(fn)
    @proc_nodes.walk_ast(fn)
    @stm_nodes.walk_ast(fn)
  end
end

class Sequence < Node
  attr_reader :nodes

  def initialize(nodes)
    super("seq")
    @nodes = nodes
  end
  
  def to_s
    s = "(\n"
    @@indent += 1
    for node in @nodes
      s += indent + node.to_s + "\n" if !node.nil?
    end
    @@indent -= 1
    s = s + indent + ")"
    s
  end

  def walk_ast(fn)
    super(fn)
    @nodes.each {|node| node.walk_ast(fn) if !node.nil?}
  end
end

class Proc < Node
  attr_reader :proc
  attr_reader :stms
  
  def initialize(proc, stms)
    super(proc.name)
    @proc = proc
    @stms = stms
  end

  def to_s
    s = "(" + @name
    @@indent += 1
    s += " " + @stms.to_s
    @@indent -= 1
    s += "\n" + close_node(true)
  end

  def walk_ast(fn)
    super(fn)
    @stms.walk_ast(fn)
  end
end

class Statement < Node
  
end

class BinaryExpression < Statement
  attr_reader :lexp
  attr_reader :rexp
  
  def initialize(name, lexp, rexp, node_type)
    super(name, node_type)
    @lexp = lexp
    @rexp = rexp
    
    # determine what the valid types are for the expressions on the right and left
    valid_types = []
    case name
    when "-", "/", "%"
      valid_types = [:int]
    when "+", "*"
      valid_types = [:int, :bool]
    when "=", "!="
      valid_types = [:int, :bool]
    when ">", "<", ">=", "<="
      valid_types = [:int]
    end
    
    valid = false
    for valid_type in valid_types
      if valid_type == :int
        if @lexp.node_type.is_int && @rexp.node_type.is_int
          valid = true
          break
        end
      elsif valid_type == :bool
        if @lexp.node_type.is_bool && @rexp.node_type.is_bool
          valid = true
          break
        end
      elsif valid_type == :string
        if @lexp.node_type.is_string && @rexp.node_type.is_string
          valid = true
          break
        end
      end
    end
    if !valid
      raise SemanticError, "incompatible types (" + @lexp.node_type.to_s + ", " + @rexp.node_type.to_s + ") in expression for '#{name}' operator"
    end
  end

  def to_s
    super([@lexp, @rexp])
  end

  def walk_ast(fn)
    super(fn)
    @lexp.walk_ast(fn)
    @rexp.walk_ast(fn)
  end
end

class UnaryExpression < Statement
  attr_reader :exp
  
  def initialize(name, exp, node_type)
    super(name, node_type)
    @exp = exp

    valid = false
    case name
    when "-"
      valid = true if @exp.node_type.is_int || @exp.node_type.is_bool
    when "?"
      valid = true if @exp.node_type.is_bool
    end

    if !valid
      raise SemanticError, "invalid type (" + @exp.node_type.to_s + ") in expression for unary '#{name}' operator"
    end
  end

  def to_s
    super([@exp])
  end

  def walk_ast(fn)
    super(fn)
    @exp.walk_ast(fn)
  end
end

class Write < Statement
  attr_reader :exp
  
  def initialize(name, exp)
    super(name)
    @exp = exp

    valid = true if @exp.node_type.is_string || @exp.node_type.is_int
    if !valid
      raise SemanticError, "invalid type (" + @exp.node_type.to_s + ") in expression for unary '#{name}' operator"
    end
  end

  def to_s
    super([@exp])
  end

  def walk_ast(fn)
    super(fn)
    @exp.walk_ast(fn)
  end
end

class Literal < Statement
  attr_reader :value
  attr_accessor :mem_address    # for strings only
  
  def initialize(node_type, value)
    super(node_type.to_s, node_type)
    @value = value
  end

  def to_s
    if @node_type.is_string
      super(["\"" + @value + "\"" ])
    else
      super([@value])
    end
  end
end

class Control < Statement
end

class Call < Statement
  attr_reader :proc
  attr_reader :args

  def initialize(proc, args, node_type)
    super("call", node_type)
    @proc = proc
    @args = args
  end
  
  def to_s
    s = "(call " + proc.name + " ("
    for arg in args
        s = s + arg.to_s
    end
    s += close_node
    s += ")"
  end

  def walk_ast(fn)
    super(fn)
    args.each {|arg| arg.walk_ast(fn)}
  end
end

class ForLoop < Statement
  attr_reader :id
  attr_reader :begin_range
  attr_reader :end_range
  attr_reader :statements
  
  def initialize(name, id, begin_range, end_range, statements)
    super(name)
    @id = id
    @begin_range = begin_range
    @end_range = end_range
    @statements = statements
  end
  
  def to_s
    s = "(for " + @id.to_s + " = " + @begin_range.to_s + ".." + @end_range.to_s
    if !@statements.nil?
      @@indent += 1
      s = s + " " + @statements.to_s 
    @@indent -= 1
    end
    s += "\n" + close_node(true)
  end

  def walk_ast(fn)
    super(fn)
    @id.walk_ast(fn)
    @begin_range.walk_ast(fn)
    @end_range.walk_ast(fn)
    @statements.walk_ast(fn)
  end
end

class WhileLoop < Statement
  attr_reader :exp
  attr_reader :statements
  
  def initialize(name, exp, stms)
    super(name)
    @exp = exp
    @statements = stms
  end
  
  def to_s
    s = "(while " + @exp.to_s
    if !@statements.nil?
      @@indent += 1
      s = s + " " + @statements.to_s 
    @@indent -= 1
    end
    s += "\n" + close_node(true)
  end

  def walk_ast(fn)
    super(fn)
    @exp.walk_ast(fn)
    @statements.walk_ast(fn)
  end
end

class Read < Statement
end

class Assignment < Statement
  attr_reader :id
  attr_reader :exp
  
  def initialize(name, id, exp)
    @id = id
    @exp = exp
    super(name)

    valid = false
    if @id.node_type.is_int && @exp.node_type.is_int
      valid = true
    elsif @id.node_type.is_bool && @exp.node_type.is_bool
      valid = true
    elsif @id.node_type.is_string && @exp.node_type.is_string
      valid = true
    end
    
    if !valid
      raise SemanticError, "incompatible types (" + @id.node_type.to_s + ", " + @exp.node_type.to_s + ") in expression for '#{name}' operator"
    end
  end
  
  def to_s
    super([@id, @exp])
  end

  def walk_ast(fn)
    super(fn)
    @id.walk_ast(fn)
    @exp.walk_ast(fn)
  end
end

class Identifier < Statement
  attr_reader :var

  def initialize(var)
    super("id", var.var_type)
    @var = var
  end

  def to_s
    super([@var.name])
  end
end

class Indice < Statement
  attr_reader :id
  attr_reader :exp
  attr_reader :array_size
  
  def initialize(name, id, exp, array_size, node_type)
    super(name, node_type)
    @id = id
    @exp = exp
    @array_size = array_size
  end
  
  def to_s
    super([@id, @exp])
  end

  def walk_ast(fn)
    super(fn)
    @id.walk_ast(fn)
    @exp.walk_ast(fn)
  end
end

class IfElse < Statement
  attr_reader :exp
  attr_reader :statements
  attr_reader :else_node
  
  def initialize(name, exp, statements, else_node = nil)
    super(name)
    @exp = exp
    @statements = statements
    @else_node = else_node
  end

  def to_s
    # if or elseif
    s = "(" + @name
    
    # expression
    s += " " + exp.to_s + " "

    @@indent += 1

    # if/elseif true statements
    s += @statements.to_s

    # else false statements
    s += "\n" + indent + @else_node.to_s if !@else_node.nil?

    @@indent -= 1
    s += "\n" + close_node(true)
    s
  end

  def walk_ast(fn)
    super(fn)
    @exp.walk_ast(fn)
    @statements.walk_ast(fn)
    @else_node.walk_ast(fn) if !@else_node.nil?
  end
end

end
