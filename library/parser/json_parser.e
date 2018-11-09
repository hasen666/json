note
	description: "Parse serialized JSON data"
	author: "$Author$"
	date: "$Date$"
	revision: "$Revision$"
	EIS: "name=RFC7159", "protocol=URI", "src=https://tools.ietf.org/html/rfc7159"

class
	JSON_PARSER

inherit
	JSON_READER
		rename
			make as make_reader,
			reset as reset_reader
		end

	JSON_TOKENS

create
	make_with_string,
	make_parser

feature {NONE} -- Initialize

	make_with_string (a_content: STRING)
			-- Initialize parser with JSON content `a_content'.
		require
			a_content_not_empty: a_content /= Void and then not a_content.is_empty
		do
			create buffer_json_string.make (a_content.count.min (512))
			create errors.make
			make_reader (a_content)
			reset
		end

	make_parser (a_json: STRING)
			-- Initialize.
		obsolete
			"Use `make_with_string' [2017-05-31]."
		do
			make_with_string (a_json)
		end

feature -- Status report

	is_parsed: BOOLEAN
			-- Is parsed ?

	is_valid: BOOLEAN
			-- Is valid?
		do
			Result := not has_error
		end

	has_error: BOOLEAN
			-- Has error?

	errors: LINKED_LIST [STRING]
			-- Current errors

	errors_as_string: STRING
			-- String representation of `errors'.
		do
			create Result.make_empty
			across
				errors as ic
			loop
				Result.append_string (ic.item)
				Result.append_character ('%N')
			end
		end

	current_errors: STRING
			-- Current errors as string
		obsolete
			"Use errors_as_string [2017-05-31]"
		do
			Result := errors_as_string
		end

feature -- Settings

	default_array_size: INTEGER
			-- JSON array are initialized with `default_array_size` capability.

	default_object_size: INTEGER
			-- JSON object are initialized with `default_object_size` capability.	

feature -- Settings change

	set_default_array_size (nb: INTEGER)
			-- Set `default_array_size` to `nb`.
		do
			default_array_size := nb
		end

	set_default_object_size (nb: INTEGER)
			-- Set `default_object_size` to `nb`.	
		do
			default_object_size := nb
		end

feature -- Access

	parsed_json_value: detachable JSON_VALUE
			-- Parsed json value if any.
		require
			is_parsed: is_parsed
		attribute
		ensure
			attached_result_if_valid: is_valid implies Result /= Void
		end

	parsed_json_object: detachable JSON_OBJECT
			-- parsed json value as a JSON_OBJECT if it is an object.
		require
			is_parsed: is_parsed
		do
			if attached {JSON_OBJECT} parsed_json_value as j_object then
				Result := j_object
			end
		end

	parsed_json_array: detachable JSON_ARRAY
			-- parsed json value as a JSON_OBJECT if it is an array.
		require
			is_parsed: is_parsed
		do
			if attached {JSON_ARRAY} parsed_json_value as j_array then
				Result := j_array
			end
		end

feature -- Commands

	reset
			-- Reset parsing values.
		do
			parsed_json_value := Void
			errors.wipe_out
			has_error := False
			is_parsed := False
			buffer_json_string.wipe_out
		end

	parse_content
			-- Parse JSON content `representation'.
			-- start ::= object | array
		do
			reset
			reset_reader

			if is_valid_start_symbol then
				parsed_json_value := next_json_value
				if not has_error and extra_elements then
					report_error_at ("Remaining element outside the main json value", index)
				end
			else
				report_error_at ("Syntax error unexpected token, expecting '{' or '['", index)
			end
			is_parsed := is_valid
		end


feature -- Element change

	report_error (e: STRING)
			-- Report error `e'
		require
			e_not_void: e /= Void
		do
			has_error := True
			errors.force (e)
		ensure
			has_error: has_error
			is_not_valid: not is_valid
		end

	report_error_at (e: STRING; pos: INTEGER)
			-- Report error `e` at position `pos`.
		require
			e_not_void: e /= Void
			pos_valid: pos > 0
		do
			if pos > 0 then
				report_error (e + " (position: " + index.out + ")")
			else
				report_error (e)
			end
		ensure
			has_error: has_error
			is_not_valid: not is_valid
		end

feature -- Obsolete commands		

	parse_json: detachable JSON_VALUE
			-- Parse JSON data `representation'
			-- start ::= object | array
		obsolete
			"Use `parse_content' and `parsed_json_value'  [2017-05-31]."
		do
			parse_content
			if is_parsed then
				Result := parsed_json_value
			end
		end

	parse_object: detachable JSON_OBJECT
			-- Parse JSON data `representation'
			-- start ::= object | array
		obsolete
			"Use `parse_content' and `parsed_json_value'  [2017-05-31]."
		do
			parse_content
			if is_parsed and then attached {JSON_OBJECT} parsed_json_value as jo then
				Result := jo
			end
		end

	parse: detachable JSON_VALUE
			-- Next JSON value from current position on `representation'.
		obsolete
			"Use restricted `next_parsed_json_value' [2017-05-31]."
		do
			Result := next_parsed_json_value
			is_parsed := is_valid
		end

feature {JSON_PARSER_ACCESS} -- Obsolete commands: restricted area		

	next_parsed_json_value: detachable JSON_VALUE
			-- Return next json value from current position.
			--| this does not call `reset_reader'.
		do
			reset
			Result := next_json_value
		end

feature {NONE} -- Implementation: parsing

	next_json_value: detachable JSON_VALUE
			-- Next JSON value from current position on `representation'.
		local
			c: CHARACTER
		do
			if not has_error then
				skip_white_spaces
				c := actual
				inspect c
				when token_object_open then
					Result := next_json_object
				when token_double_quote then
					Result := parse_string
				when token_array_open then
					Result := parse_array
				else
					if c.is_digit or c = token_minus then
						Result := parse_number
					elseif is_null then
						Result := create {JSON_NULL}
						next
						next
						next
					elseif is_true then
						Result := create {JSON_BOOLEAN}.make_true
						next
						next
						next
					elseif is_false then
						Result := create {JSON_BOOLEAN}.make_false
						next
						next
						next
						next
					else
						report_error_at ("JSON value is not well formed", index)
						Result := Void
					end
				end
			end
		ensure
			is_parsed_implies_result_not_void: not has_error implies Result /= Void
		end

	next_json_object: JSON_OBJECT
			-- object
			-- {}
			-- {"key" : "value" [,]}
		local
			has_more: BOOLEAN
			l_json_string: detachable JSON_STRING
			l_value: detachable JSON_VALUE
		do
			create Result.make_with_capacity (default_object_size)
				--| check if is an empty object {}
			next
			skip_white_spaces
			if actual = token_object_close then
					--| is an empty object
			else
					--| a complex object {"key" : "value"}
				previous
				from
					has_more := True
				until
					not has_more
				loop
					next
					skip_white_spaces
					l_json_string := parse_string
					next
					skip_white_spaces
					if actual = token_colon then --| token_colon = ':'
						next
						skip_white_spaces
					else
						report_error_at ("%N Input string is a not well formed JSON, expected [:] found [" + actual.out + "]", index)
						has_more := False
					end
					l_value := next_json_value
					if not has_error and then (l_value /= Void and l_json_string /= Void) then
						Result.put (l_value, l_json_string)
						next
						skip_white_spaces
						if actual = token_object_close then
							has_more := False
						elseif actual /= token_comma then
							has_more := False
							report_error_at ("JSON Object syntactically malformed expected , found [" + actual.out + "]", index)
						end
					else
						has_more := False
							-- explain the error
					end
				end
			end
		end

	parse_string: detachable JSON_STRING
			-- Parsed string
		local
			has_more: BOOLEAN
--			l_json_string: STRING
			l_unicode: STRING
			c: like actual
			buf: like buffer_json_string
		do
			-- create l_json_string.make_empty
			buf := buffer_json_string
			buf.wipe_out
			if actual = token_double_quote then
				from
					has_more := True
				until
					not has_more
				loop
					next
					c := actual
					if c = token_double_quote then
						has_more := False
					elseif c = '%H' then -- '%H' = '\' = reverse solidus
						next
						c := actual
						if c = 'u' then
							create l_unicode.make_from_string ("\u")
							read_unicode_info (l_unicode)

							c := actual
							if is_valid_unicode (l_unicode) then
								--- l_json_string.append (l_unicode)
								buf.append (l_unicode)
							else
								has_more := False
								report_error_at ("Input string is not well formed JSON, expected Unicode value, found [" + c.out + "]", index)
							end
						elseif (not is_special_character (c) and not is_special_control (c)) or c = '%N' then
							has_more := False
							report_error_at ("Input string is not well formed JSON, found [" + c.out + "]", index)
						else
							--l_json_string.append_character ('\')
							buf.append_character ('\')
							--l_json_string.append_character (c)
							buf.append_character (c)
						end
					else
						if is_special_character (c) and c /= '/' then
							has_more := False
							report_error_at ("Input string is not well formed JSON, found [" + c.out + "]", index)
						elseif c = '%U' then
								--| Accepts null character in string value.
							 -- l_json_string.append_character (c)
							buf.append_character (c)
						else
							 -- l_json_string.append_character (c)
							buf.append_character (c)
						end
					end
				end
				create Result.make_from_escaped_json_string (buf.twin)
			else
				Result := Void
			end
		end

	parse_array: JSON_ARRAY
			-- array
			-- []
			-- [elements [,]]
		local
			flag: BOOLEAN
			l_value: detachable JSON_VALUE
			c: like actual
		do
			create Result.make (default_array_size)
				-- check if is an empty array []
			next
			skip_white_spaces
			if actual = token_array_close then
					-- is an empty array
			else
				previous
				from
					flag := True
				until
					not flag
				loop
					next
					skip_white_spaces
					l_value := next_json_value
					if not has_error and then l_value /= Void then
						Result.add (l_value)
						next
						skip_white_spaces
						c := actual
						if c = token_array_close then
							flag := False
						elseif c /= token_comma then
							flag := False
							report_error_at ("Array is not well formed JSON, found [" + c.out + "]", index)
						end
					else
						flag := False
						report_error_at ("Array is not well formed JSON, found [" + actual.out + "]", index)
					end
				end
			end
		end

	parse_number: detachable JSON_NUMBER
			-- Parsed number
		local
			sb: STRING
			flag: BOOLEAN
			is_integer: BOOLEAN
			c: like actual
		do
			create sb.make_empty
			sb.append_character (actual)
			from
				flag := True
			until
				not flag
			loop
				next
				c := actual
				if not has_next or is_close_token (c) or c = token_comma or c = '%N' or c = '%R' then
					flag := False
					previous
				else
					sb.append_character (c)
				end
			end

			if is_valid_number (sb) then
				if sb.is_integer_64 then
					create Result.make_integer (sb.to_integer_64)
					is_integer := True
				elseif sb.is_double and not is_integer then
					create Result.make_real (sb.to_double)
				end
			else
				report_error_at ("Expected a number, found [" + sb + "]", index)
			end
		end

	is_null: BOOLEAN
			-- Word at index represents null?
		local
			l_null: STRING
			l_string: STRING
		do
			l_null := null_id
			-- l_string := json_substring (index, index + l_null.count - 1)
			create l_string.make_from_string (json_substring (index, index + l_null.count - 1))
			if l_string.is_equal (l_null) then
				Result := True
			end
		end

	is_false: BOOLEAN
			-- Word at index represents false?
		local
			l_false: STRING
			l_string: STRING
		do
			l_false := false_id
			 -- l_string := json_substring (index, index + l_false.count - 1)
			create l_string.make_from_string (json_substring (index, index + l_false.count - 1))
			if l_string.is_equal (l_false) then
				Result := True
			end
		end

	is_true: BOOLEAN
			-- Word at index represents true?
		local
			l_true: STRING
			l_string: STRING
		do
			l_true := true_id
			--l_string := json_substring (index, index + l_true.count - 1)
			create l_string.make_from_string (json_substring (index, index + l_true.count - 1))
			if l_string.is_equal (l_true) then
				Result := True
			end
		end

	read_unicode_info (a_content: STRING)
			-- Read unicode and return value.
		local
			i: INTEGER
		do
			from
				i := 1
			until
				i > 4 or not has_next
			loop
				next
				a_content.append_character (actual)
				i := i + 1
			end
		end

feature {NONE} -- Implementation

	is_valid_number (a_number: STRING): BOOLEAN
			-- is 'a_number' a valid number based on this regular expression
			-- "-?(?: 0|[1-9]\d+)(?: \.\d+)?(?: [eE][+-]?\d+)?\b"?
		local
			s: detachable STRING
			c: CHARACTER
			i, n: INTEGER
		do
			create s.make_empty
			n := a_number.count
			if n = 0 then
				Result := False
			else
				Result := True
				i := 1
					--| "-?"
				c := a_number [i]
				if c = token_minus then
					s.extend (c)
					i := i + 1
					if i > n then
						Result := False
					else
						c := a_number [i]
					end
				end
					--| "0|[1-9]\d*
				if Result and c.is_digit then
					if c = '0' then
							--| "0"
						s.extend (c)
						i := i + 1
						if i <= n then
							c := a_number [i]
						end
					else
							--| "[1-9]"
						s.extend (c)

							--| "\d*"
						i := i + 1
						if i <= n then
							c := a_number [i]
							from
							until
								i > n or not c.is_digit
							loop
								s.extend (c)
								i := i + 1
								if i <= n then
									c := a_number [i]
								end
							end
						end
					end
				end
			end
			if i > n then
					-- Exit
			else
				if Result then
						--| "(\.\d+)?"
					if c = token_dot then
							--| "\.\d+"  =  "\.\d\d*"
						s.extend (c)
						i := i + 1
						c := a_number [i]
						if c.is_digit then
							from
							until
								i > n or not c.is_digit
							loop
								s.extend (c)
								i := i + 1
								if i <= n then
									c := a_number [i]
								end
							end
						else
							Result := False --| expecting digit
						end
					end
				end
				if Result then --| "(?:[eE][+-]?\d+)?\b"
					if is_exp_token (c) then
							--| "[eE][+-]?\d+"
						s.extend (c)
						i := i + 1
						c := a_number [i]
						if c = token_plus or c = token_minus then
							s.extend (c)
							i := i + 1
							if i <= n then
								c := a_number [i]
							end
						end
						if c.is_digit then
							from
							until
								i > n or not c.is_digit
							loop
								s.extend (c)
								i := i + 1
								if i <= n then
									c := a_number [i]
								end
							end
						else
							Result := False --| expecting digit
						end
					end
				end
				if Result then --| "\b"
					from
					until
						i > n or not c.is_space
					loop
						s.extend (c)
						i := i + 1
						if i <= n then
							c := a_number [i]
						end
					end
					Result := i > n and then s.same_string (a_number)
				end
			end
		end

	is_valid_unicode (a_unicode: STRING): BOOLEAN
			-- is 'a_unicode' a valid unicode based on the regular expression "\\u[0-9a-fA-F]{4}" .
		local
			i: INTEGER
		do
			if a_unicode.count = 6 and then a_unicode [1] = '\' and then a_unicode [2] = 'u' then
				from
					Result := True
					i := 3
				until
					i > 6 or Result = False
				loop
					inspect a_unicode [i]
					when '0'..'9', 'a'..'f', 'A'..'F' then
					else
						Result := False
					end
					i := i + 1
				end
			end
		end

	extra_elements: BOOLEAN
			-- has more elements?
		local
			c: like actual
		do
			if has_next then
				next
			end
			from
				c := actual
			until
				c /= ' ' or c /= '%R' or c /= '%U' or c /= '%T' or c /= '%N' or not has_next
			loop
				next
			end
			Result := has_next
		end

	is_valid_start_symbol: BOOLEAN
			-- expecting `{' or `[' as start symbol
		do
			if attached representation as s and then s.count > 0 then
				Result := s [1] = token_object_open or s [1] = token_array_open
			end
		end

feature {NONE} -- Constants

	false_id: STRING = "false"

	true_id: STRING = "true"

	null_id: STRING = "null"


feature {NONE} -- JSON String Buffer

	buffer_json_string: STRING
			-- JSON string buffer.

;note
	copyright: "2010-2018, Javier Velilla, Jocelyn Fiat, Eiffel Software and others https://github.com/eiffelhub/json."
	license: "https://github.com/eiffelhub/json/blob/master/License.txt"
end
