
//# feather use syntax-errors

run_test(function() : Test("lexer-misc-unicode") constructor {
    var buff = __catspeak_create_buffer_from_string(@'🙀會意字 abcde1');
    var lexer = new CatspeakLexer(buff);
    // other
    assertEq(CatspeakToken.OTHER, lexer.nextWithWhitespace());
    assertEq("🙀", lexer.getLexeme());
    // other
    assertEq(CatspeakToken.OTHER, lexer.nextWithWhitespace());
    assertEq("會", lexer.getLexeme());
    // other
    assertEq(CatspeakToken.OTHER, lexer.nextWithWhitespace());
    assertEq("意", lexer.getLexeme());
    // other
    assertEq(CatspeakToken.OTHER, lexer.nextWithWhitespace());
    assertEq("字", lexer.getLexeme());
    // whitespace
    assertEq(CatspeakToken.WHITESPACE, lexer.nextWithWhitespace());
    assertEq(" ", lexer.getLexeme());
    // identifier
    assertEq(CatspeakToken.IDENT, lexer.nextWithWhitespace());
    assertEq("abcde1", lexer.getLexeme());
    buffer_delete(buff);
});

run_test(function() : TestLexerTokenStream("lexer-misc-example",
    "return (fun (a, b) { a + b })"
) constructor {
    checkTokens(
        CatspeakToken.RETURN,
        CatspeakToken.PAREN_LEFT,
        CatspeakToken.FUN,
        CatspeakToken.PAREN_LEFT,
        CatspeakToken.IDENT,
        CatspeakToken.COMMA,
        CatspeakToken.IDENT,
        CatspeakToken.PAREN_RIGHT,
        CatspeakToken.BRACE_LEFT,
        CatspeakToken.IDENT,
        CatspeakToken.OP_ADD,
        CatspeakToken.IDENT,
        CatspeakToken.BRACE_RIGHT,
        CatspeakToken.PAREN_RIGHT
    )
});

run_test(function() : TestLexerTokenStream("lexer-misc-example-2",
    @'
        count = 0
        limit = 10
        while (count < limit) {
            inc_count()
            count = count + 1
        }
        return count
    '
) constructor {
    checkTokens(
        CatspeakToken.BREAK_LINE,
        CatspeakToken.IDENT,
        CatspeakToken.ASSIGN,
        CatspeakToken.NUMBER,
        CatspeakToken.BREAK_LINE,
        CatspeakToken.IDENT,
        CatspeakToken.ASSIGN,
        CatspeakToken.NUMBER,
        CatspeakToken.BREAK_LINE,
        CatspeakToken.WHILE,
        CatspeakToken.PAREN_LEFT,
        CatspeakToken.IDENT,
        CatspeakToken.OP_COMP,
        CatspeakToken.IDENT,
        CatspeakToken.PAREN_RIGHT,
        CatspeakToken.BRACE_LEFT,
        CatspeakToken.IDENT,
        CatspeakToken.PAREN_LEFT,
        CatspeakToken.PAREN_RIGHT,
        CatspeakToken.BREAK_LINE,
        CatspeakToken.IDENT,
        CatspeakToken.ASSIGN,
        CatspeakToken.IDENT,
        CatspeakToken.OP_ADD,
        CatspeakToken.NUMBER,
        CatspeakToken.BREAK_LINE,
        CatspeakToken.BRACE_RIGHT,
        CatspeakToken.BREAK_LINE,
        CatspeakToken.RETURN,
        CatspeakToken.IDENT,
        CatspeakToken.BREAK_LINE
    )
});

run_test(function() : TestLexerTokenStream("lexer-misc-example-3",
    @'
        
        
        ; ;
        
         ; ;
        ;
        
 ; hi ; 
 ; ;; ;
 
                                                        ...
    '
) constructor {
    checkTokens(
        CatspeakToken.BREAK_LINE,
        CatspeakToken.IDENT,
        CatspeakToken.BREAK_LINE,
        CatspeakToken.OP_LOW // ;;
    )
});