' TEST_MODE : COMPILE_ONLY_FAIL

type T
	as integer i
	declare sub test( )
	protected:
	static x as integer
end type

dim T.x as integer

T.x = 123
