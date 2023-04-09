//! Responsible for the lexical analysis stage of the Catspeak compiler.

//# feather use syntax-errors

/// A token in Catspeak is a series of characters with meaning, usually
/// separated by whitespace.
///
/// For example, these are all valid tokens:
///   - `if`   (is a `CatspeakToken.IF`)
///   - `else` (is a `CatspeakToken.ELSE`)
///   - `12.3` (is a `CatspeakToken.NUMBER`)
///   - `+`    (is a `CatspeakToken.OP_ADD`)
///
/// The following enum represents all possible token types understood by the
/// Catspeak language.
enum CatspeakToken {
    /// The `(` character.
    PAREN_LEFT,
    /// The `)` character.
    PAREN_RIGHT,
    /// The `[` character.
    BOX_LEFT,
    /// The `]` character.
    BOX_RIGHT,
    /// The `{` character.
    BRACE_LEFT,
    /// The `}` character.
    BRACE_RIGHT,
    /// The `.` character.
    DOT,
    /// The `:` character.
    COLON,
    /// The `,` character.
    COMMA,
    /// The `=` character.
    ASSIGN,
    /// The `do` keyword.
    DO,
    /// The `it` keyword.
    IT,
    /// The `if` keyword.
    IF,
    /// The `else` keyword.
    ELSE,
    /// The `while` keyword.
    WHILE,
    /// The `for` keyword.
    FOR,
    /// The `loop` keyword.
    LOOP,
    /// The `let` keyword.
    LET,
    /// The `fun` keyword.
    FUN,
    /// The `break` keyword.
    BREAK,
    /// The `continue` keyword.
    CONTINUE,
    /// The `return` keyword.
    RETURN,
    /// The `and` keyword.
    AND,
    /// The `or` keyword.
    OR,
    /// The `new` keyword.
    NEW,
    /// The `impl` keyword.
    IMPL,
    /// The `self` keyword.
    SELF,
    /// Represents a variable name.
    IDENT,
    /// Represents a GML string value.
    STRING,
    /// Represents a GML numeric value. This could be one of:
    ///  - integer:   1, 2, 5
    ///  - float:     1.25, 0.5
    ///  - character: 'A', '0', '\n'
    NUMBER,
    /// Represents a sequence of non-breaking whitespace characters.
    WHITESPACE,
    /// Represents a comment.
    COMMENT,
    /// Represents a sequence of newline or `;` characters.
    BREAK_LINE,
    /// The `...` operator.
    CONTINUE_LINE,
    /// Represents the end of the file.
    EOF,
    /// Represents any other unrecognised character.
    OTHER,
    __OPERATORS_BEGIN__,
    /// Represents any operator identifier starting with `$`, `:`, or `;`.
    OP_LOW,
    /// Represents any operator identifier starting with `^` or `|`.
    OP_OR,
    /// Represents any operator identifier starting with `&`.
    OP_AND,
    /// Represents any operator identifier starting with
    ///   `!`, `<`, `=`, `>`, `?` or `~`.
    OP_COMP,
    /// Represents any operator identifier starting with `+` or `-`.
    OP_ADD,
    /// Represents any operator identifier starting with `*` or `/`.
    OP_MUL,
    /// Represents any operator identifier starting with `%` or `\`.
    OP_DIV,
    /// Represents any operator identifier starting with `#`, `.` or `@`.
    OP_HIGH,
    __OPERATORS_END__,
    __SIZE__
}

/// Returns whether a Catspeak token is a valid operator.
///
/// @param {Enum.CatspeakToken} token
///   The ID of the token to check.
///
/// @return {Bool}
function catspeak_token_is_operator(token) {
    gml_pragma("forceinline");
    if (CATSPEAK_DEBUG_MODE) {
        __catspeak_check_typeof_numeric("token", token);
    }
    return token > CatspeakToken.__OPERATORS_BEGIN__
            && token < CatspeakToken.__OPERATORS_END__;
}

/// @ignore
///
/// @param {String} src
/// @return {Id.Buffer}
function __catspeak_create_buffer_from_string(src) {
    var capacity = string_byte_length(src);
    var buff = buffer_create(capacity, buffer_fixed, 1);
    buffer_write(buff, buffer_text, src);
    buffer_seek(buff, buffer_seek_start, 0);
    return buff;
}

/// Responsible for tokenising the contents of a GML buffer. This can be used
/// for syntax highlighting in a programming game which uses the Catspeak
/// engine.
///
/// NOTE: The lexer does not take ownership of this buffer, but it may mutate
///       it so beware. Therefore you should make sure to delete the buffer
///       once parsing is complete.
///
/// @param {Id.Buffer} buff
///   The ID of the GML buffer to use.
///
/// @param {Real} [offset]
///   The offset in the buffer to start parsing from. Defaults to 0, the
///   start of the buffer.
///
/// @param {Real} [size]
///   The length of the buffer input. Any characters beyond this limit will
///   be treated as the end of the file. Defaults to `infinity`.
function CatspeakLexer(buff, offset=0, size=infinity) constructor {
    if (CATSPEAK_DEBUG_MODE) {
        __catspeak_check_init();
        __catspeak_check_typeof_numeric("buff", buff);
        __catspeak_check_typeof_numeric("offset", offset);
        __catspeak_check_typeof_numeric("size", size);
    }

    self.buff = buff;
    self.buffAlignment = buffer_get_alignment(buff);
    self.buffCapacity = buffer_get_size(buff);
    self.offset = clamp(offset, 0, self.buffCapacity);
    self.size = clamp(size, 0, self.buffCapacity);
    self.row = 1;
    self.column = 1;
    self.lexemeStart = 0;
    self.lexemeEnd = 0;
    self.lexemePos = catspeak_location_create(self.row, self.column);
    self.lexeme = undefined;
    self.value = undefined;
    self.charCurr = 0;
    self.charNext = __nextUTF8Char();
    self.skipNextSemicolon = false;

    /// @ignore
    ///
    /// @return {Real}
    static __nextUTF8Char = function () {
        if (offset >= size) {
            return 0;
        }
        var byte = buffer_peek(buff, offset, buffer_u8);
        offset += 1;
        if ((byte & 0b10000000) == 0) {
            // ASCII digit
            return byte;
        }
        var codepointCount;
        var headerMask;
        // parse UTF8 header, could maybe hand-roll a binary search
        if ((byte & 0b11111100) == 0b11111100) {
            codepointCount = 5;
            headerMask = 0b11111100;
        } else if ((byte & 0b11111000) == 0b11111000) {
            codepointCount = 4;
            headerMask = 0b11111000;
        } else if ((byte & 0b11110000) == 0b11110000) {
            codepointCount = 3;
            headerMask = 0b11110000;
        } else if ((byte & 0b11100000) == 0b11100000) {
            codepointCount = 2;
            headerMask = 0b11100000;
        } else if ((byte & 0b11000000) == 0b11000000) {
            codepointCount = 1;
            headerMask = 0b11000000;
        } else {
            //__catspeak_error("invalid UTF8 header codepoint '", byte, "'");
            return -1;
        }
        // parse UTF8 continuations (2 bit header, followed by 6 bits of data)
        var dataWidth = 6;
        var utf8Value = (byte & ~headerMask) << (codepointCount * dataWidth);
        for (var i = codepointCount - 1; i >= 0; i -= 1) {
            byte = buffer_peek(buff, offset, buffer_u8);
            offset += 1;
            if ((byte & 0b10000000) == 0) {
                //__catspeak_error("invalid UTF8 continuation codepoint '", byte, "'");
                return -1;
            }
            utf8Value |= (byte & ~0b11000000) << (i * dataWidth);
        }
        return utf8Value;
    };

    /// @ignore
    static __advance = function () {
        lexemeEnd = offset;
        if (charNext == ord("\r")) {
            column = 1;
            row += 1;
        } else if (charNext == ord("\n")) {
            column = 1;
            if (charCurr != ord("\r")) {
                row += 1;
            }
        } else {
            column += 1;
        }
        // actually update chars now
        charCurr = charNext;
        charNext = __nextUTF8Char();
    };

    /// @ignore
    static __clearLexeme = function () {
        lexemeStart = lexemeEnd;
        lexemePos = catspeak_location_create(self.row, self.column);
        lexeme = undefined;
        value = undefined;
    };

    /// @ignore
    ///
    /// @param {Real} start
    /// @param {Real} end_
    static __slice = function (start, end_) {
        var buff_ = buff;
        // don't read outside bounds of `size`
        var clipStart = min(start, size);
        var clipEnd = min(end_, size);
        if (clipEnd <= clipStart) {
            // always an empty slice
            if (CATSPEAK_DEBUG_MODE && clipEnd < clipStart) {
                __catspeak_error_bug();
            }
            return "";
        } else if (clipEnd >= buffCapacity) {
            // beyond the actual capacity of the buffer
            // not safe to use `buffer_string`, which expects a null char
            return buffer_peek(buff_, clipStart, buffer_text);
        } else {
            // quickly write a null terminator and then read the content
            var byte = buffer_peek(buff_, clipEnd, buffer_u8);
            buffer_poke(buff_, clipEnd, buffer_u8, 0x00);
            var result = buffer_peek(buff_, clipStart, buffer_string);
            buffer_poke(buff_, clipEnd, buffer_u8, byte);
            return result;
        }
    };

    /// Returns the string representation of the most recent token emitted by
    /// the [next] or [nextWithWhitespace] methods.
    ///
    /// @example
    ///   Prints the string content of the first [CatspeakToken] emitted by a
    ///   lexer.
    ///
    /// ```gml
    /// lexer.next();
    /// show_debug_message(lexer.getLexeme());
    /// ```
    ///
    /// @return {String}
    static getLexeme = function () {
        lexeme ??= __slice(lexemeStart, lexemeEnd);
        return lexeme;
    };

    /// @ignore
    ///
    /// @param {String} str
    static __getKeyword = function (str) {
        var keyword = global.__catspeakString2Token[$ str];
        if (CATSPEAK_DEBUG_MODE && keyword != undefined) {
            // the user can modify what keywords are, so just check
            // that they've used one of the enum types instead of a
            // random ass value
            __catspeak_check_typeof_numeric("keyword", keyword);
            if (
                keyword < 0 || keyword >= CatspeakToken.__SIZE__ ||
                keyword == CatspeakToken.__OPERATORS_BEGIN__ ||
                keyword == CatspeakToken.__OPERATORS_END__
            ) {
                __catspeak_error(
                    __catspeak_location_show(getLocation()), ": ",
                    "custom keyword aliases must map to a numeric ",
                    "type corresponding to a `CatspeakToken`, e.g. ",
                    "`keywords[$ \"func\"] = CatspeakToken.FUN;`"
                );
            }
        }
        return keyword;
    };

    /// Returns the actual value representation of the most recent token
    /// emitted by the [next] or [nextWithWhitespace] methods.
    ///
    /// NOTE: Unlike [getLexeme] this value is not always a string. For numeric
    ///       literals, the value will be converted into an integer or real.
    ///
    /// @return {Any}
    static getValue = function () {
        value ??= getLexeme();
        return value;
    };

    /// Returns the location information for the most recent token emitted by
    /// the [next] or [nextWithWhitespace] methods.
    ///
    /// @return {Real}
    static getLocation = function () {
        return catspeak_location_create(row, column);
    };

    /// Advances the lexer and returns the next type of [CatspeakToken]. This
    /// includes additional whitespace and control tokens, like:
    ///  - line breaks `;`          (`CatspeakToken.BREAK_LINE`)
    ///  - line continuations `...` (`CatspeakToken.CONTINUE_LINE`)
    ///  - comments `--`            (`CatspeakToken.COMMENT`)
    ///
    /// To get the string content of the token, you should use the [getLexeme]
    /// method.
    ///
    /// @example
    ///   Iterates through all tokens of a buffer containing Catspeak code,
    ///   printing each non-whitespace token out as a debug message.
    ///
    /// ```gml
    /// var lexer = new CatspeakLexer(buff);
    /// do {
    ///   var token = lexer.nextWithWhitespace();
    ///   if (token != CatspeakToken.WHITESPACE) {
    ///     show_debug_message(lexer.getLexeme());
    ///   }
    /// } until (token == CatspeakToken.EOF);
    /// ```
    ///
    /// @return {Enum.CatspeakToken}
    static nextWithWhitespace = function () {
        __clearLexeme();
        if (charNext == 0) {
            return CatspeakToken.EOF;
        }
        __advance();
        var token = CatspeakToken.OTHER;
        var charCurr_ = charCurr; // micro-optimisation, locals are faster
        if (charCurr_ >= 0 && charCurr_ < __CATSPEAK_CODEPAGE_SIZE) {
            token = global.__catspeakChar2Token[charCurr_];
        }
        if (charCurr_ == ord("\"")) {
            // strings
            // TODO
        } else if (charCurr_ == ord("@") && charNext == ord("\"")) {
            // raw strings
            token = CatspeakToken.STRING; // since `@` is an operator
            __advance();
            // TODO
        } else if (catspeak_token_is_operator(token)) {
            // operator identifiers
            while (__catspeak_char_is_operator(charNext)) {
                __advance();
            }
            var keyword = __getKeyword(getLexeme());
            if (keyword != undefined) {
                token = keyword;
                if (keyword == CatspeakToken.COMMENT) {
                    // consume the comment
                    lexeme = undefined; // since the lexeme is now invalid
                                        // we have more work to do
                    while (true) {
                        var charNext_ = charNext;
                        if (
                            charNext_ == ord("\n") ||
                            charNext_ == ord("\r") ||
                            charNext_ == 0
                        ) {
                            break;
                        }
                        __advance();
                    }
                }
            }
        } else if (charCurr_ == ord("`")) {
            // literal identifiers
            while (true) {
                var charNext_ = charNext;
                if (
                    charNext_ == ord("`") || charNext_ == 0 ||
                    __catspeak_char_is_whitespace(charNext_)
                ) {
                    break;
                }
                __advance();
            }
            value = __slice(lexemeStart + 1, lexemeEnd);
            if (charNext == ord("`")) {
                __advance();
            }
        } else if (token == CatspeakToken.IDENT) {
            // alphanumeric identifiers
            while (__catspeak_char_is_alphanumeric(charNext)) {
                __advance();
            }
            var keyword = __getKeyword(getLexeme());
            if (keyword != undefined) {
                token = keyword;
            }
        } else if (charCurr_ == ord("'")) {
            // character literals
            __advance();
            value = charCurr;
            if (charNext == ord("'")) {
                __advance();
            }
        } else if (token == CatspeakToken.NUMBER) {
            // numeric literals
            var hasUnderscores = false;
            var hasDecimal = false;
            while (true) {
                var charNext_ = charNext;
                if (__catspeak_char_is_digit(charNext_)) {
                    __advance();
                } else if (charNext_ == ord("_")) {
                    __advance();
                    hasUnderscores = true;
                } else if (!hasDecimal && charNext_ == ord(".")) {
                    __advance();
                    hasDecimal = true;
                } else {
                    break;
                }
            }
            var digits = getLexeme();
            if (hasUnderscores) {
                digits = string_replace_all(digits, "_", "");
            }
            value = real(digits);
        }
        return token;
    };

    /// Advances the lexer and returns the next [CatspeakToken], ingoring
    /// any comments, whitespace, and line continuations.
    ///
    /// To get the string content of the token, you should use the [getLexeme]
    /// method.
    ///
    /// @example
    ///   Iterates through all tokens of a buffer containing Catspeak code,
    ///   printing each token out as a debug message.
    ///
    /// ```gml
    /// var lexer = new CatspeakLexer(buff);
    /// do {
    ///   var token = lexer.next();
    ///   show_debug_message(lexer.getLexeme());
    /// } until (token == CatspeakToken.EOF);
    /// ```
    ///
    /// @return {Enum.CatspeakToken}
    static next = function () {
        var skipSemicolon = skipNextSemicolon;
        skipNextSemicolon = false;
        var tokenSkipsNewlinePage = global.__catspeakTokenSkipsNewline;
        while (true) {
            var token = nextWithWhitespace();
            if (token == CatspeakToken.WHITESPACE
                    || token == CatspeakToken.COMMENT) {
                continue;
            }
            if (token == CatspeakToken.CONTINUE_LINE) {
                skipSemicolon = true;
                continue;
            } else if (tokenSkipsNewlinePage[token]) {
                skipNextSemicolon = true;
            }
            if (skipSemicolon && token == CatspeakToken.BREAK_LINE) {
                continue;
            }
            return token;
        }
    };
}

/// @ignore
#macro __CATSPEAK_CODEPAGE_SIZE 256

/// @ignore
function __catspeak_init_lexer() {
    // initialise map from character to token type
    global.__catspeakChar2Token = __catspeak_init_lexer_codepage();
    global.__catspeakString2Token = __catspeak_init_lexer_keywords();
    global.__catspeakTokenSkipsNewline = __catspeak_init_lexer_newlines();
}

/// @ignore
function __catspeak_char_is_digit(char) {
    gml_pragma("forceinline");
    return char >= ord("0") && char <= ord("9");
}

/// @ignore
function __catspeak_char_is_alphanumeric(char) {
    gml_pragma("forceinline");
    return char >= ord("a") && char <= ord("z") ||
            char >= ord("A") && char <= ord("Z") ||
            char >= ord("0") && char <= ord("9") ||
            char == ord("_");
}

/// @ignore
function __catspeak_char_is_operator(char) {
    gml_pragma("forceinline");
    return char >= ord("!") && char <= ord("&") && char != ord("\"") ||
            char >= ord("*") && char <= ord("/") && char != ord(",") ||
            char >= ord(":") && char <= ord("@") ||
            char == ord("\\") || char == ord("^") ||
            char == ord("|") || char == ord("~");
}

/// @ignore
function __catspeak_char_is_whitespace(char) {
    gml_pragma("forceinline");
    return char >= 0x09 && char <= 0x0D || char == 0x20 || char == 0x85;
}

/// @ignore
function __catspeak_codepage_value(code) {
    gml_pragma("forceinline");
    return is_string(code) ? ord(code) : code;
}

/// @ignore
function __catspeak_codepage_range(code, minCode, maxCode) {
    gml_pragma("forceinline");
    var codeVal = __catspeak_codepage_value(code);
    var minVal = __catspeak_codepage_value(minCode);
    var maxVal = __catspeak_codepage_value(maxCode);
    return codeVal >= minVal && codeVal <= maxVal;
}

/// @ignore
function __catspeak_codepage_set(code) {
    gml_pragma("forceinline");
    var codeVal = __catspeak_codepage_value(code);
    for (var i = 1; i < argument_count; i += 1) {
        if (codeVal == __catspeak_codepage_value(argument[i])) {
            return true;
        }
    }
    return false;
}

/// @ignore
function __catspeak_init_lexer_codepage() {
    var page = array_create(__CATSPEAK_CODEPAGE_SIZE, CatspeakToken.OTHER);
    for (var code = 0; code < __CATSPEAK_CODEPAGE_SIZE; code += 1) {
        var tokenType;
        if (__catspeak_codepage_set(code,
            0x09, // CHARACTER TABULATION ('\t')
            0x0B, // LINE TABULATION      ('\v')
            0x0C, // FORM FEED            ('\f')
            0x20, // SPACE                (' ')
            0x85  // NEXT LINE
        )) {
            tokenType = CatspeakToken.WHITESPACE;
        } else if (__catspeak_codepage_set(code,
            0x0A, // LINE FEED            ('\n')
            0x0D  // CARRIAGE RETURN      ('\r')
        )) {
            tokenType = CatspeakToken.BREAK_LINE;
        } else if (
            __catspeak_codepage_range(code, "a", "z") ||
            __catspeak_codepage_range(code, "A", "Z") ||
            __catspeak_codepage_set(code, "_", "`") // identifier literals
        ) {
            tokenType = CatspeakToken.IDENT;
        } else if (
            __catspeak_codepage_range(code, "0", "9") ||
            __catspeak_codepage_set(code, "'") // character literals
        ) {
            tokenType = CatspeakToken.NUMBER;
        } else if (__catspeak_codepage_set(code, "$", ":", ";")) {
            tokenType = CatspeakToken.OP_LOW;
        } else if (__catspeak_codepage_set(code, "^", "|")) {
            tokenType = CatspeakToken.OP_OR;
        } else if (__catspeak_codepage_set(code, "&")) {
            tokenType = CatspeakToken.OP_AND;
        } else if (__catspeak_codepage_set(code, "!", "<", "=", ">", "?", "~")) {
            tokenType = CatspeakToken.OP_COMP;
        } else if (__catspeak_codepage_set(code, "+", "-")) {
            tokenType = CatspeakToken.OP_ADD;
        } else if (__catspeak_codepage_set(code, "*", "/")) {
            tokenType = CatspeakToken.OP_MUL;
        } else if (__catspeak_codepage_set(code, "%", "\\")) {
            tokenType = CatspeakToken.OP_DIV;
        } else if (__catspeak_codepage_set(code, "#", ".", "@")) {
            tokenType = CatspeakToken.OP_HIGH;
        } else if (__catspeak_codepage_set(code, "\"")) {
            tokenType = CatspeakToken.STRING;
        } else if (__catspeak_codepage_set(code, "(")) {
            tokenType = CatspeakToken.PAREN_LEFT;
        } else if (__catspeak_codepage_set(code, ")")) {
            tokenType = CatspeakToken.PAREN_RIGHT;
        } else if (__catspeak_codepage_set(code, "[")) {
            tokenType = CatspeakToken.BOX_LEFT;
        } else if (__catspeak_codepage_set(code, "]")) {
            tokenType = CatspeakToken.BOX_RIGHT;
        } else if (__catspeak_codepage_set(code, "{")) {
            tokenType = CatspeakToken.BRACE_LEFT;
        } else if (__catspeak_codepage_set(code, "}")) {
            tokenType = CatspeakToken.BRACE_RIGHT;
        } else if (__catspeak_codepage_set(code, ",")) {
            tokenType = CatspeakToken.COMMA;
        } else {
            continue;
        }
        page[@ code] = tokenType;
    }
    return page;
}

/// @ignore
function __catspeak_init_lexer_keywords() {
    var keywords = { };
    keywords[$ "--"] = CatspeakToken.COMMENT;
    keywords[$ "="] = CatspeakToken.ASSIGN;
    keywords[$ ":"] = CatspeakToken.COLON;
    keywords[$ ";"] = CatspeakToken.BREAK_LINE;
    keywords[$ "."] = CatspeakToken.DOT;
    keywords[$ "..."] = CatspeakToken.CONTINUE_LINE;
    keywords[$ "do"] = CatspeakToken.DO;
    keywords[$ "it"] = CatspeakToken.IT;
    keywords[$ "if"] = CatspeakToken.IF;
    keywords[$ "else"] = CatspeakToken.ELSE;
    keywords[$ "while"] = CatspeakToken.WHILE;
    keywords[$ "for"] = CatspeakToken.FOR;
    keywords[$ "loop"] = CatspeakToken.LOOP;
    keywords[$ "let"] = CatspeakToken.LET;
    keywords[$ "fun"] = CatspeakToken.FUN;
    keywords[$ "break"] = CatspeakToken.BREAK;
    keywords[$ "continue"] = CatspeakToken.CONTINUE;
    keywords[$ "return"] = CatspeakToken.RETURN;
    keywords[$ "and"] = CatspeakToken.AND;
    keywords[$ "or"] = CatspeakToken.OR;
    keywords[$ "new"] = CatspeakToken.NEW;
    keywords[$ "impl"] = CatspeakToken.IMPL;
    keywords[$ "self"] = CatspeakToken.SELF;
    global.__catspeakConfig.keywords = keywords;
    return keywords;
}

/// @ignore
function __catspeak_init_lexer_newlines() {
    var page = array_create(CatspeakToken.__SIZE__, false);
    var tokens = [
        // !! DO NOT ADD `BREAK_LINE` HERE, IT WILL RUIN EVERYTHING !!
        //              you have been warned... (*^_^*) b
        CatspeakToken.PAREN_LEFT,
        CatspeakToken.BOX_LEFT,
        CatspeakToken.BRACE_LEFT,
        CatspeakToken.DOT,
        CatspeakToken.COLON,
        CatspeakToken.COMMA,
        CatspeakToken.ASSIGN,
        // this token technically does, but it's handled in a different
        // way to the others, so it's only here honorarily
        //CatspeakToken.CONTINUE_LINE,
        CatspeakToken.DO,
        CatspeakToken.IF,
        CatspeakToken.ELSE,
        CatspeakToken.WHILE,
        CatspeakToken.FOR,
        CatspeakToken.LET,
        CatspeakToken.FUN,
        CatspeakToken.OP_LOW,
        CatspeakToken.OP_OR,
        CatspeakToken.OP_AND,
        CatspeakToken.OP_COMP,
        CatspeakToken.OP_ADD,
        CatspeakToken.OP_MUL,
        CatspeakToken.OP_DIV,
        CatspeakToken.OP_HIGH,
    ];
    var count = array_length(tokens);
    for (var i = 0; i < count; i += 1) {
        page[@ tokens[i]] = true;
    }
    return page;
}