#
# Nice9.rex
# lexical scanner definition for rex
#

class Nice9

macro
  WSPACE        [\ \t]+
  ID            [A-Za-z][A-Za-z0-9_]*
  INT           [0-9]+
  DQSTRING      "[^"\n]*"
  SQSTRING      '[^'\n]*'
  
rule
  {WSPACE}
  \#[^\n]*
  if            { [:TK_IF, text] }
  elseif        { [:TK_ELSEIF, text] }
  else          { [:TK_ELSE, text] }
  while         { [:TK_WHILE, text] }
  then          { [:TK_THEN, text] }
  for           { [:TK_FOR, text] }
  to            { [:TK_TO, text] }
  proc          { [:TK_PROC, text] }
  end           { [:TK_END, text] }
  return        { [:TK_RETURN, text] }
  forward       { [:TK_FOWARD, text] }
  var           { [:TK_VAR, text] }
  type          { [:TK_TYPE, text] }
  break         { [:TK_BREAK, text] }
  exit          { [:TK_EXIT, text] }
  true          { [:TK_TRUE, text] }
  false         { [:TK_FALSE, text] }
  write         { [:TK_WRITE, text] }
  writes        { [:TK_WRITES, text] }
  read          { [:TK_READ, text] }
  {ID}          { [:TK_ID, text] }
  \(            { [:TK_LPAREN, text] }
  \)            { [:TK_RPAREN, text] }
  \[            { [:TK_LBRACK, text] }
  \]            { [:TK_RBRACK, text] }
  \:\=          { [:TK_ASSIGN, text] }
  \:            { [:TK_COLON, text] }
  \;            { [:TK_SEMI, text] }
  \?            { [:TK_QUEST, text] }
  \,            { [:TK_COMMA, text] }
  \+            { [:TK_PLUS, text] }
  \-            { [:TK_MINUS, text] }
  \*            { [:TK_STAR, text] }
  \/            { [:TK_SLASH, text] }
  \%            { [:TK_MOD, text] }
  \=            { [:TK_EQ, text] }
  \!\=          { [:TK_NEQ, text] }
  \>\=          { [:TK_GE, text] }
  \<\=          { [:TK_LE, text] }
  \>            { [:TK_GT, text] }
  \<            { [:TK_LT, text] }
  \n
  {INT}         { [:TK_INT, text.to_i] }
  {SQSTRING}    { [:TK_SLIT, text] }
  {DQSTRING}    { [:TK_SLIT, text] }
inner

def abc
end

end
