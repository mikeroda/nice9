require 'ast'

class Nice9Writer
  def initialize(output_file)
    @out = output_file
  end

  def preamble
  end

  def epilogue
  end

  def generate_code(top_node)
  end

  def gen_code(node)
  end
end

class TinyMachineWriter < Nice9Writer
 
  # special registers
  ZERO = 0    # zero
  AC = 1      # accumulator
  SP = 4      # stack pointer
  FP = 5      # frame pointer
  PC = 7      # program counter

  def initialize(output_file)
    super(output_file)

    # output tiny machine line number
    @line = 0
  
    # registers:
    @registers = [ 6, 3, 2 ]   # see reserved registers below    

    # location 0 has the memory size so we start at 1
    @heap_pointer = 1
    
    # array of line numbers that return statements occur on, for back-patching with a jump later
    @return_stms = []
    
    # array of line numbers that exit statements occur on, for back-patching with a jump later
    @exit_stms = []
    
    # stack of arrays holding line numbers for break statements, for batch-patching with a jump later
    @breaks = []
  end

  def alloc_strings(node)
    if node.kind_of?(AST::Literal) && node.node_type.is_string
      @out.write ".DATA " + node.value.length.to_s + "\n"
      @out.write ".SDATA \"" + node.value + "\"\n"
      node.mem_address = @heap_pointer
      
      @heap_pointer += node.value.length + 1
    end
  end
  
  def generate_code(top_node)
    
    # store all the string literals in memory
    top_node.walk_ast(method(:alloc_strings))

    @array_index_out_of_bounds_string = @heap_pointer
    @out.write ".DATA 32\n"    
    @out.write ".SDATA \"Error: Array index out of bounds\"\n"
    @heap_pointer += 33

    # allocate memory for global variables, memory offsets are absolute addresses (on the heap)
    @heap_pointer += alloc_var_memory(top_node.vars.values, @heap_pointer, 1, true)

    # allocate memory for all the for loop variables
    @heap_pointer += alloc_forloop_vars(top_node.stm_nodes, @heap_pointer, 1, true)

    # preamble
    @out.write " * BEGIN preample\n"
    output_instruction("LD" , 4, 0, 0, "store top of stack in register 4")
    @out.write " * END preample\n"

    @line += 1    # leave a space for jumping over the procs

    begin_proc = @line   # keep track of where the procedures start

    # output code to write the array index out of bounds error and halt
    @out.write " * BEGIN array_index_out_of_bounds code\n"
    @array_index_out_of_bounds = @line
    output_instruction("LDA", AC, @array_index_out_of_bounds_string, ZERO, "load address of error routine")
    write_string
    output_instruction("OUTNL", 0, 0, 0)
    output_instruction("HALT", 0, 0, 0)
    @out.write " * END array_index_out_of_bounds code\n"

    # generate the code for the procedures
    gen_code(top_node.proc_nodes)
    end_proc = @line

    gen_array_bounds
    
    @line = begin_proc - 1
    output_instruction("LDA", PC, end_proc - begin_proc, PC, "jump over the procedure code")
    @line = end_proc
    
    gen_code(top_node.stm_nodes)
    
    # backpatch all the return and exit statements with a jump to the end of the program
    epilogue = @line
    @exit_stms += @return_stms
    while @exit_stms.length > 0
      @line = @exit_stms.pop
      output_instruction("JEQ", ZERO, epilogue, ZERO, "jump to end of program")    
    end

    # halt at the end of the program
    @line = epilogue
    output_instruction("HALT", 0, 0, 0)
  end

  def gen_array_bounds
    
  end

  def pad(str, n)
    s = ""
    for i in 1..(n - str.length) 
      s += " "
    end
    s
  end

  def output_instruction(opcode, r, s, t, comment = "") 

    # determine the type of instruction
    case opcode
      when "HALT"
        register_only = true
      when "IN", "OUT", "INB", "OUTB", "OUTC", "OUTNL"
        register_only = true
      when "ADD", "SUB", "MUL", "DIV"
        register_only = true
      when "LDC", "LDA", "LD"
        register_only = false
      when "ST"
        register_only = false
      when "JLT", "JLE", "JEQ", "JNE", "JGE", "JGT"
        register_only = false
      end
    
    buff = pad(@line.to_s, 4) + @line.to_s + ":" + pad(opcode, 8) + opcode

    buff += " #{r},"
    if register_only
      buff += " #{s},#{t}"
    else
      buff += " #{s}(#{t})"
    end
      
    buff += pad("", 25 - buff.length) + comment + "\n"
    @out.write buff
    @line += 1
  end

  def alloc_forloop_vars(node, offset, direction, is_global)
    size = 0
    size += alloc_var_memory(node.vars.values, offset, direction, is_global) if node.kind_of?(AST::ForLoop)
    offset += (size * direction)

    child_nodes = []
    if node.kind_of?(AST::Sequence)
      child_nodes = node.nodes
    elsif node.kind_of?(AST::IfElse)
      child_nodes = [node.statements, node.else_node]
    elsif node.kind_of?(AST::WhileLoop) || node.kind_of?(AST::ForLoop)
      child_nodes = [node.statements]
    elsif node.kind_of?(AST::Proc)
      child_nodes = node.stms.nodes
    end

    # call recursively for any child nodes that might have a for loop
    for child_node in child_nodes
      size += alloc_forloop_vars(child_node, offset, direction, is_global)
    end

    size
  end
  
  def alloc_var_memory(vars, offset, direction, is_global)

    total_size = 0
    for var in vars
      next if var.mem_offset != nil
#      puts "var " + var.name + " will go in offset " + offset.to_s
        var.mem_offset = offset    # variable will start at the offset
        var.is_global = is_global

        # determine the space required by the variable
        size = 1
        
        if var.mem_contains != :reference
          size *= var.var_type.array_size if var.var_type.is_array

          if !var.var_type.basic_type
            underlying_type = var.var_type.underlying_type
            while underlying_type.is_array
              size *= underlying_type.array_size
              underlying_type = underlying_type.underlying_type
            end
          end
        end

        total_size += size
        offset += (size * direction)   # calculate the next offset
    end
    
    total_size
  end

  # method to get the memory address of an Identifier node, which could be nested within
  # 1 or more Indice nodes. Result is left in the accumulator register
  def get_mem_address(node)
    
    if node.kind_of?(AST::Identifier)
      if node.var.is_global 
        output_instruction("LDA", AC, node.var.mem_offset, ZERO, "load memory address of variable")
      else
        output_instruction("LDA", AC, node.var.mem_offset, FP, "load memory address of variable")
      end
    else
      # begin the memory offset at 0 - global vars are offset from 0
      output_instruction("LDC", AC, 0, 0)

      # loop calculates the array offset and leaves in the accumulator
      while node.kind_of?(AST::Indice)
        # store the memory offset on the stack
        output_instruction("ST", AC, 0, SP, "move memory offset to stack")
        output_instruction("LDA", SP, -1, SP, "decrement stack pointer")
        
        # generate the expression
        gen_code(node.exp)

        reg = @registers.pop   # get a new register

        # check array bounds
        output_instruction("JLT", AC, @array_index_out_of_bounds, ZERO)
        output_instruction("LDC", reg, node.array_size, 0)   # array bounds
        output_instruction("LDA", reg, -1, reg)              # subract 1 from max since we start at 0
        output_instruction("SUB", reg, reg, AC)
        output_instruction("JLT", reg, @array_index_out_of_bounds, ZERO)
        
        if node.node_type.array_size > 0
          output_instruction("LDC", reg, node.node_type.array_size, 0)
          output_instruction("MUL", AC, AC, reg)
        end
        
        # get a register and get the memory offset off the stack
        output_instruction("LDA", SP, 1, SP, "increment stack pointer")
        output_instruction("LD", reg, 0, SP, "move memory offset from stack")

        output_instruction("ADD", AC, AC, reg)

        @registers.push(reg)   # done with the register

        node = node.id
      end

      # at this point, the accumulator holds the total offset within the array

      reg = @registers.pop   # get a new register
      output_instruction("LDC", reg, node.var.mem_offset, 0, "get variable memory offset")

      if !node.var.is_global
        # calculate address of variable in stack
        output_instruction("ADD", reg, reg, FP, "calculate var address inside activation record")
        
        if node.var.mem_contains == :reference
          output_instruction("LD", reg, 0, reg, "load reference")
        end
      end
            
      output_instruction("ADD", AC, reg, AC, "add array offset to base offset of variable")
      @registers.push(reg)   # done with the register

    end
  end

  def gen_code(node, evaluation = :pass_by_value)
    if node.kind_of?(AST::Sequence)
      gen_sequence(node)
    elsif node.kind_of?(AST::Proc)
      gen_proc(node)
    elsif node.kind_of?(AST::Control)
      gen_control(node)
    elsif node.kind_of?(AST::Call)
      gen_call(node)
    elsif node.kind_of?(AST::BinaryExpression)
      gen_binary_expression(node)
    elsif node.kind_of?(AST::UnaryExpression)
      gen_unary_expression(node)
    elsif node.kind_of?(AST::Literal)
      gen_literal(node)
    elsif node.kind_of?(AST::Read)
      gen_read(node)
    elsif node.kind_of?(AST::Write)
      gen_write(node)
    elsif node.kind_of?(AST::Identifier)
      gen_identifier(node)
    elsif node.kind_of?(AST::Indice)
      gen_indice(node, evaluation)
    elsif node.kind_of?(AST::Assignment)
      gen_assignment(node)
    elsif node.kind_of?(AST::IfElse)
      gen_if_else(node)
    elsif node.kind_of?(AST::WhileLoop)
      gen_do_loop(node)
    elsif node.kind_of?(AST::ForLoop)
      gen_for_loop(node)
    else
      super(node)
    end
  end
  
  ######################################################################################
  #  Methods to generate code
  ######################################################################################
  
  def gen_sequence(node)
    for node in node.nodes
        gen_code(node) if !node.nil?
    end
  end

  # generate the code for a procedure.
  # 
  # activation record is as follows, starting from the frame pointer:
  # 0 : return address
  # 1 : saved frame pointer
  # 2 : return variable
  # 
  def gen_proc(node)
    node.proc.mem_address = @line
    @out.write " * BEGIN procedure " + node.name + "\n"

    node.proc.activation_rec_size = 1        # return address
    node.proc.activation_rec_size += 1       # previous frame pointer (if any)

    node.proc.activation_rec_size += 1       # stack pointer, needed in case we return abruptly
    output_instruction("ST", SP, -2, FP, "save the stack pointer")

    # return value
    if !node.proc.return_var.nil?
      node.proc.return_var.mem_offset = node.proc.activation_rec_size * -1
      if node.proc.return_var.var_type.is_int || node.proc.return_var.var_type.is_bool
        node.proc.activation_rec_size += 1      # integers and booleans use 1 word of memory
      end
    end

    # allocate memory for arguments
    node.proc.activation_rec_size += alloc_var_memory(node.proc.args, (node.proc.activation_rec_size * -1), -1, false)

    # allocate memory for local variables
    node.proc.activation_rec_size += alloc_var_memory(node.vars.values, (node.proc.activation_rec_size * -1), -1, false)

    # allocate memory for all the for-loop variables
    node.proc.activation_rec_size += alloc_forloop_vars(node, (node.proc.activation_rec_size * -1), -1, false)

    gen_code(node.stms)
   
    # backpatch all the return statements with a jump back to the end of the procedure
    begin_return = @line
    while @return_stms.length > 0
      @line = @return_stms.pop
      output_instruction("JEQ", ZERO, begin_return, ZERO, "jump to end of procedure")    
    end
    @line = begin_return

    output_instruction("LD", SP, -2, FP, "reset the stack pointer")

    if !node.proc.return_var.nil?
      # move the return value into the accumulator
      output_instruction("LD", AC, node.proc.return_var.mem_offset, FP, "copy return value into AC")
    end
    
    output_instruction("LDA", SP, node.proc.activation_rec_size, SP, "move stack pointer over activation record")

    # reset the frame pointer and return from procedure
    output_instruction("LD", FP, -1, SP, "reset the the frame pointer")
    output_instruction("LD", PC, 0, SP, "return from procedure")
    
    @out.write " * END procedure " + node.name + "\n"
  end
  
  def gen_control(node)
    @out.write " * back-patch line " + @line.to_s + ", " + node.name + " statement\n"

    case node.name
      when "return"
        @return_stms.push(@line)
        
      when "exit"
        @exit_stms.push(@line)
        
      when "break"
        @breaks.last.push(@line)
      end

      @line += 1     # leave a space for a jump
  end

  def gen_call(node)

    # evaluate argument expressions and copy results into the activation record
    for n in 0..node.args.length - 1
      gen_code(node.args[n], :pass_by_reference) if !node.args[n].nil?
      output_instruction("ST", AC, node.proc.args[n].mem_offset, SP)
    end

    num_cmds = 5

    # calculate and push return address on the stack
    output_instruction("LDA", AC, num_cmds, PC, "calculate return address")
    output_instruction("ST", AC, 0, SP, "push return address on stack")

    # push current frame pointer on the stack
    output_instruction("ST", FP, -1, SP, "push frame pointer on stack")

    # set frame pointer equal to the stack pointer
    output_instruction("LDA", FP, 0, SP, "set frame pointer")

    output_instruction("LDA", SP, node.proc.activation_rec_size * -1, SP, "decrement the stack pointer")

    output_instruction("LDC", PC, node.proc.mem_address, 0, "jump to procedure")
  end

  def gen_binary_expression(node)
    # generate the left side expression
    gen_code(node.lexp)
    
    bool_and_or = false
    if (node.name == "+" || node.name == "*") && node.lexp.node_type.is_bool && node.rexp.node_type.is_bool
      bool_and_or = true
      # leave a line to backpatch later with a jump for short-circuiting
      after_lexp = @line 
      @line += 1
      
      # generate the right side expression
      gen_code(node.rexp)

      save_line = @line
      @line = after_lexp

      if node.name == "+"
        opcode = "JNE"
      elsif node.name == "*"
        opcode = "JEQ"
      end

      output_instruction(opcode, AC, save_line - after_lexp - 1, PC, "short-circuit jump")
      @line = save_line
    else
      # put left side expression on the stack
      output_instruction("ST", AC, 0, SP, "move left exp onto stack")
      output_instruction("LDA", SP, -1, SP, "decrement the stack pointer")
    
      # generate the right side expression
      gen_code(node.rexp)
    
      # get a register and move the left side expression off the stack
      output_instruction("LDA", SP, 1, SP, "increment the stack pointer")
      reg = @registers.pop
      output_instruction("LD", reg, 0, SP, "move left exp from stack")
 
      desc = node.name + " binary arithmetic operator"
      opcode = nil
      case node.name
      when "+"
        opcode = "ADD"
      when "-"
        opcode = "SUB"
      when "*"
        opcode = "MUL"
      when "/"
        opcode = "DIV"
      when "<", ">", "<=", ">=", "=", "!="
        opcode = "SUB"
        desc = "subtract expressions"
      end

      output_instruction(opcode, AC, reg, AC, desc) if !opcode.nil?

      # special code needed to handle modula
      if node.name == "%"
        reg2 = @registers.pop
        output_instruction("LDA", reg2, 0, AC)
        output_instruction("DIV", AC, reg, reg2)
        output_instruction("MUL", AC, AC, reg2)
        output_instruction("SUB", AC, reg, AC)
        @registers.push(reg2)
      end

      @registers.push(reg)      # done with register containing the left expression

      opcode = nil
      case node.name
      when "<"
        opcode = "JLT"
      when ">"
        opcode = "JGT"
      when "<="
        opcode = "JLE"
      when ">="
        opcode = "JGE"
      when "="
        opcode = "JEQ"
      when "!="
        opcode = "JNE"
      end
    
      if !opcode.nil?
        output_instruction(opcode, AC, 2, PC, node.name + " comparison operator")

        output_instruction("LDC", AC, 0, ZERO, "false expression")
        output_instruction("JEQ", ZERO, 1, PC, "jump over next instruction")

        output_instruction("LDC", AC, 1, ZERO, "true expression")
      end
    end
  end

  def gen_unary_expression(node)
    # generate the expression and put it on the stack
    gen_code(node.exp)

    if node.name == "-"
      reg = @registers.pop
      output_instruction("LDC", reg, -1, 0)
      if node.exp.node_type.is_bool
        output_instruction("ADD", AC, AC, reg)
        output_instruction("MUL", AC, AC, reg)
      elsif node.exp.node_type.is_int
        output_instruction("MUL", AC, AC, reg)
      end
      @registers.push(reg)      # done with register containing the left expression
    end
  end

  def gen_read(node)
    output_instruction("IN", AC, 0, 0, "read integer")
  end

  # Method to write out a string. Address of the string is assumed to be in the accumulator, 
  # where that address stores the size of the string and then the characters follow.
  # Pops return address off the stack and jumps there.
  def write_string
      reg1 = @registers.pop  # get a register to iterate through the string
      reg2 = @registers.pop  # get a register to load each character into
      output_instruction("LD", reg1, 0, AC)       # load size of string
      output_instruction("LDA", AC, 1, AC)        # point accumulator to first character
      
      begin_loop = @line
      @line += 1   # save place to back-patch a jump
      
      output_instruction("LD", reg2, 0, AC)       # load character from memory
      output_instruction("OUTC", reg2, 0, 0)      # output character
      output_instruction("LDA", AC, 1, AC)        # go to the next character
      output_instruction("LDA", reg1, -1, reg1)   # decrement num of characters left to read
      output_instruction("JEQ", ZERO, begin_loop - @line - 1, PC)   # jump to beginning of loop

      end_loop = @line
      
      @line = begin_loop
      output_instruction("JEQ", reg1, end_loop - begin_loop - 1, PC)   # jump to end if no chars left

      @line = end_loop
      @registers.push(reg1)
      @registers.push(reg2)
  end

  def gen_write(node)
    gen_code(node.exp)

    if (node.exp.node_type.is_int)
      output_instruction("OUT", AC, 0, 0, "write integer")
    else
      write_string
    end

    output_instruction("OUTNL", 0, 0, 0, "newline for write statement") if node.name == "write"
  end

  def gen_literal(node)
    if node.node_type.is_string
      output_instruction("LDA", AC, node.mem_address, ZERO, "address of string literal")
    else
      output_instruction("LDC", AC, node.value, 0, node.name + " literal")
    end
  end
  
  # get the value stored in memory for the variable represented by this identifier
  # and copy it into the accumulator
  def gen_identifier(node)
    get_mem_address(node)
    output_instruction("LD" , AC, 0, AC, "get contents of var " + node.var.name) if !node.node_type.is_array
  end

  def gen_indice(node, evaluation)

    # get the address to load from memory
    get_mem_address(node)

    output_instruction("LD" , AC, 0, AC, "load value from memory") if evaluation == :pass_by_value
  end
  
  def gen_assignment(node)
    # evaluate the expression and push the value on the stack
    gen_code(node.exp)
    output_instruction("ST", AC, 0, SP, "move exp onto stack")
    output_instruction("LDA", SP, -1, SP, "decrement the stack pointer")

    # get the memory address to store the expression into
    get_mem_address(node.id)

    # get the expression value back off the stack and put it in a register
    reg = @registers.pop
    output_instruction("LDA", SP, 1, SP, "increment the stack pointer")
    output_instruction("LD", reg, 0, SP, "move left exp from stack")

    output_instruction("ST" , reg, 0, AC, "assign value of expression into memory")
    
    @registers.push(reg)
  end
  
  def gen_if_else(node)
    # generate the expression
    gen_code(node.exp)

    # leave a gap for the jump
    @line += 1
    if_begin = @line
    
    # generate if/elseif true code
    gen_code(node.statements)

    if_end = @line

    if !node.else_node.nil?
      # leave a gap for the jump over the else instructions
      @line += 1
      if_end = @line

      # generate the else code
      gen_code(node.else_node)
      
      # backpatch the if/elseif true code to jump over the else statements
      save_line = @line
      @line = if_end - 1
      output_instruction("JEQ", ZERO, save_line - @line - 1, PC, "jump over the else statements")
      @line = save_line
    end

    save_line = @line
    @line = if_begin - 1

    # backpatch to jump over the statements if the condition is false
    output_instruction("JEQ", AC, if_end - if_begin, PC, "jump over the if statements")
    @line = save_line
  end

  def gen_do_loop(node)
    # push a new array of breaks for this loop
    @breaks.push(Array.new)
    
    exp_begin = @line   # save beginning of expression

    # generate the expression
    gen_code(node.exp)

    # leave a gap for a jump statement
    @line += 1
    stms_begin = @line   # beginning of statements in loop
    
    # generate statements inside loop
    gen_code(node.statements)
    
    # jump back to the beginning of the loop
    output_instruction("JEQ", ZERO, exp_begin - @line - 1, PC, "jump back to beginning of loop")
    loop_end = @line

    # backpatch to jump over the statements in the loop if expression false
    @line = stms_begin - 1
    output_instruction("JEQ", AC, loop_end - stms_begin, PC, "jump over the statements in loop")
    @line = loop_end

    # backpatch all the break statements with a jump back to the end of the loop
    while @breaks.last.length > 0
      @line = @breaks.last.pop
      output_instruction("JEQ", ZERO, loop_end - @line - 1, PC, "break")    
    end
    @line = loop_end

    @breaks.pop
  end

  def gen_for_loop(node)
    # push a new array of breaks for this loop
    @breaks.push(Array.new)

    # set the initial value of the loop variable
    gen_code(node.begin_range)             # result of expression in accumulator
    reg = @registers.pop
    output_instruction("LDA" ,reg, 0, AC)  # copy accumulator into new register
    get_mem_address(node.id)               # get the mem address of the loop variable 
    output_instruction("ST" , reg, 0, AC, "set initial value of var " + node.id.var.name)
    @registers.push(reg)

    # generate the end range expression (one-time) and put it on the stack
    gen_code(node.end_range)
    output_instruction("ST", AC, 0, SP, "put ending value on the stack")
    output_instruction("LDA", SP, -1, SP, "decrement the stack pointer")   # must pop after loop ends

    # start of the loop, this is where we jump back to each time
    start_loop = @line

    # load the loop ending value and the loop current value into registers, subtract them, and do a
    # jump (back-patched later) based on the result
    reg = @registers.pop
    output_instruction("LD", reg, 1, SP, "get end value off the stack")   # get off stack but don't change stack pointer
    get_mem_address(node.id)                    # get the mem address of the loop variable 
    output_instruction("LD" , AC, 0, AC)        # get current value of the loop variable
    output_instruction("SUB" , AC, reg, AC)     # subract current value from the ending value
    @registers.push(reg)
   
    jump_line = @line
    @line += 1     # leave a gap for the jump
    
    # generate the expression
    gen_code(node.statements)

    # increment the loop variable
    reg = @registers.pop
    get_mem_address(node.id)                # get the mem address of the loop var, keep it in the accumulator 
    output_instruction("LD" , reg, 0, AC)   # get current value of the loop variable
    output_instruction("LDA", reg, 1, reg, "increment the loop variable")
    output_instruction("ST" , reg, 0, AC)   # get current value of the loop variable
    @registers.push(reg)

    output_instruction("JEQ", ZERO, start_loop - @line - 1, PC, "jump to start of for loop")

    # end of the for loop
    loop_end = @line
    
    @line = jump_line
    output_instruction("JLT", AC, loop_end - jump_line - 1, PC, "jump to end of for loop")
    @line = loop_end

    # backpatch all the break statements with a jump back to the end of the loop
    while @breaks.last.length > 0
      @line = @breaks.last.pop
      output_instruction("JEQ", ZERO, loop_end - @line - 1, PC, "break")    
    end
    @line = loop_end

    # pop the loop ending value off the stack
    output_instruction("LDA", SP, 1, SP, "increment the stack pointer x")

    @breaks.pop
  end
end
