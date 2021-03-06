note
	description: "JSON Numbers, octal and hexadecimal formats are not used."
	author: "$Author$"
	date: "$Date$"
	revision: "$Revision$"
	license: "MIT (see http://www.opensource.org/licenses/mit-license.php)"

class
	JSON_NUMBER

inherit
	JSON_VALUE
		redefine
			is_equal,
			is_number
		end

create
	make_integer, make_natural, make_real

feature {NONE} -- initialization

	make_integer (an_argument: INTEGER_64)
			-- Initialize an instance of JSON_NUMBER from the integer value of `an_argument'.
		do
			item := an_argument.out
			numeric_type := integer_type
		end

	make_natural (an_argument: NATURAL_64)
			-- Initialize an instance of JSON_NUMBER from the unsigned integer value of `an_argument'.
		do
			item := an_argument.out
			numeric_type := natural_type
		end

	make_real (an_argument: REAL_64)
			-- Initialize an instance of JSON_NUMBER from the floating point value of `an_argument'.
		do
			if an_argument.is_nan then
				item := nan_real_value
			elseif an_argument.is_negative_infinity then
				item := negative_infinity_real_value
			elseif an_argument.is_positive_infinity then
				item := positive_infinity_real_value
			else
				item := an_argument.out
			end
			numeric_type := double_type
		end

feature -- Status report			

	is_number: BOOLEAN = True
			-- <Precursor>

feature {NONE} -- REAL constants

	nan_real_value: IMMUTABLE_STRING_8
		once
			create Result.make_from_string ("NaN")
		end

	negative_infinity_real_value: IMMUTABLE_STRING_8
		once
			create Result.make_from_string ("-Infinity")
		end

	positive_infinity_real_value: IMMUTABLE_STRING_8
		once
			create Result.make_from_string ("Infinity")
		end

feature -- Access

	item: READABLE_STRING_8
			-- Content

	numeric_type: INTEGER
			-- Type of number (integer, natural or real).

	hash_code: INTEGER
			--Hash code value
		do
			Result := item.hash_code
		end

	representation: STRING
		local
			l_item: like item
		do
			l_item := item
			if
				is_real and then
				(
					l_item = nan_real_value or else
					l_item = negative_infinity_real_value or else
					l_item = positive_infinity_real_value
				)
			then
				Result := {JSON_NULL}.representation
			else
				Result := l_item.to_string_8
			end
		end

feature -- Conversion

	integer_64_item: INTEGER_64
			-- Associated integer value.
		require
			is_integer: is_integer
		do
			Result := item.to_integer_64
		end

	natural_64_item: NATURAL_64
			-- Associated natural value.
		require
			is_natural: is_natural
		do
			Result := item.to_natural_64
		end

	double_item, real_64_item: REAL_64
			-- Associated real value.
		require
			is_real: is_real
		do
			if item = nan_real_value then
				Result := {REAL_64}.nan
			elseif item = negative_infinity_real_value then
				Result := {REAL_64}.negative_infinity
			elseif item = positive_infinity_real_value then
				Result := {REAL_64}.positive_infinity
			else
				Result := item.to_real_64
			end
		end

feature -- Status report

	is_integer: BOOLEAN
			-- Is Current an integer number?
		do
			Result := numeric_type = integer_type
		end

	is_natural: BOOLEAN
			-- Is Current a natural number?
		do
			Result := numeric_type = natural_type
		end

	is_double, is_real: BOOLEAN
			-- Is Current a real number?
		do
			Result := numeric_type = real_type
		end

feature -- Visitor pattern

	accept (a_visitor: JSON_VISITOR)
			-- Accept `a_visitor'.
			-- (Call `visit_json_number' procedure on `a_visitor'.)
		do
			a_visitor.visit_json_number (Current)
		end

feature -- Status

	is_equal (other: like Current): BOOLEAN
			-- Is `other' attached to an object of the same type
			-- as current object and identical to it?
		do
			Result := item.is_equal (other.item)
		end

feature -- Status report

	debug_output: STRING
			-- String that should be displayed in debugger to represent `Current'.
		do
			Result := item.to_string_8
		end

feature -- Implementation

	integer_type: INTEGER = 1

	double_type, real_type: INTEGER = 2

	natural_type: INTEGER = 3

invariant
	item_not_void: attached item as inv_item
	nan_only_for_real: inv_item.is_case_insensitive_equal_general (nan_real_value) implies is_real
	neg_inf_only_for_real: inv_item.is_case_insensitive_equal_general (negative_infinity_real_value) implies is_real
	inf_only_for_real: inv_item.is_case_insensitive_equal_general (positive_infinity_real_value) implies is_real

note
	copyright: "2010-2019, Javier Velilla, Jocelyn Fiat, Eiffel Software and others https://github.com/eiffelhub/json."
	license: "https://github.com/eiffelhub/json/blob/master/License.txt"
end
