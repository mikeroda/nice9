#
# tmo.rex.rb - File partially generated by rex from tmo.rex, and then modified heavily.
# 
# Author: Mike Roda

require 'racc/parser'
#
# tmo.rex
# lexical scanner definition for rex
#

class Tmo < Racc::Parser
  require 'strscan'

  class ScanError < StandardError ; end

  attr_reader :lineno
  attr_reader :token
 
  def initialize
    super
    @lineno  =  1
  end

  def load_file( filename )
    str = nil
    open(filename, "r") do |f|
      str = f.read
    end
    @ss = StringScanner.new(str)
  end

  def read_stdin
    str = STDIN.read
    @ss = StringScanner.new(str)
  end

  def action &block
    yield
  end

  def parse
    do_parse
  end

  def next_token
    token_pair = nil
    text = nil
    
    until @ss.eos?
      text = @ss.peek(1)
      @lineno  +=  1  if text == "\n"
        case
        when (text = @ss.scan(/[\ \t]+/))
          ;

        when (text = @ss.scan(/\*[^\n]*\n/))
          @lineno += 1

        when (text = @ss.scan(/\.SDATA/))
           token_pair = action { [:TM_SDATA, text] }

        when (text = @ss.scan(/\.DATA/))
           token_pair =  action { [:TM_DATA, text] }

        when (text = @ss.scan(/HALT/))
           token_pair = action { [:TM_HALT, text] }

        when (text = @ss.scan(/INB/))
           token_pair = action { [:TM_INB, text] }

        when (text = @ss.scan(/IN/))
           token_pair = action { [:TM_IN, text] }

        when (text = @ss.scan(/OUTB/))
           token_pair = action { [:TM_OUTB, text] }

        when (text = @ss.scan(/OUTC/))
           token_pair = action { [:TM_OUTC, text] }

        when (text = @ss.scan(/OUTNL/))
           token_pair = action { [:TM_OUTNL, text] }

        when (text = @ss.scan(/OUT/))
           token_pair = action { [:TM_OUT, text] }

        when (text = @ss.scan(/ADD/))
           token_pair = action { [:TM_ADD, text] }

        when (text = @ss.scan(/SUB/))
           token_pair = action { [:TM_SUB, text] }

        when (text = @ss.scan(/MUL/))
           token_pair = action { [:TM_MUL, text] }

        when (text = @ss.scan(/DIV/))
           token_pair = action { [:TM_DIV, text] }

        when (text = @ss.scan(/LDC/))
           token_pair = action { [:TM_LDC, text] }

        when (text = @ss.scan(/LDA/))
           token_pair = action { [:TM_LDA, text] }

        when (text = @ss.scan(/LD/))
           token_pair = action { [:TM_LD, text] }

        when (text = @ss.scan(/ST/))
           token_pair = action { [:TM_ST, text] }

        when (text = @ss.scan(/JLT/))
           token_pair = action { [:TM_JLT, text] }

        when (text = @ss.scan(/JLE/))
           token_pair = action { [:TM_JLE, text] }

        when (text = @ss.scan(/JEQ/))
           token_pair = action { [:TM_JEQ, text] }

        when (text = @ss.scan(/JGT/))
           token_pair = action { [:TM_JGT, text] }

        when (text = @ss.scan(/JGE/))
           token_pair = action { [:TM_JGE, text] }

        when (text = @ss.scan(/JNE/))
           token_pair = action { [:TM_JNE, text] }

        when (text = @ss.scan(/\:/))
           token_pair = action { [:TM_COLON, text] }

        when (text = @ss.scan(/\,/))
           token_pair = action { [:TM_COMMA, text] }
          ;
          
        when (text = @ss.scan(/\(/))
           token_pair = action { [:TM_LPARENS, text] }
          ;
          
        when (text = @ss.scan(/\)/))
           token_pair = action { [:TM_RPARENS, text] }
          ;
          
        when (text = @ss.scan(/\-?[0-9]+/))
           token_pair = action { [:TM_INT, text.to_i] }

        when (text = @ss.scan(/"[^"\n]*"/))
           token_pair = action { [:TM_SLIT, text] }

        when (text = @ss.scan(/[^\n]*\n/))
          @lineno += 1
          
        else
          text = @ss.getch
          @token = text
          raise  ScanError, "can not match: '" + text + "'"
        end  # if

        if !token_pair.nil?
          break
        end
    end  # until @ss
    
    @token = text if !text.nil?
    
#   puts token_pair
    token_pair
  end  # def next_token

end
