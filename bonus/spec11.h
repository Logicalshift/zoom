! ====================================
! Z-Test
! Z-Machine standards compliance test
! Written by Andrew Hunter
! Specification 1.1 tests
! ====================================

Array buf -> 40;

Test saveTest "File handling test"
    with     data 1 2 3 4,
    newdata 0 0 0 0,
    Title "File handling test",
    Run [ x y z res;
	if (standard_interpreter < $101)
	{
	    print "(Your interpreter is not standard 1.1)^";
	}
	
	print "Save/restore test (no prompt)...";
	buf->0 = 40;
	@output_stream 3 buf;
	print "blarfle.file";
	@output_stream -3;
	
	print "Writing ", self.#data, " bytes to
	    blarfle.file...";
	
	x = self.&data;
	y = self.#data;
	z = buf + 1;
	
	@"EXT:0S" x y z 0 -> res;
	
	if (res == self.#data)
	{
	    x = self.&newdata;
	    @"EXT:1S" x y z 0 -> res;
	    if (res ~= self.#data)
	    {
		print "Failed: only read ", res, " bytes on restore^";
		rfalse;
	    }

	    for (x=0: x<self.#data: x++)
	    {
		if ((self.&newdata)->x ~= (self.&data)->x)
		{
		    print "Failed: byte ", x, " did not match on
			restore (read ", (self.&newdata)->x, " but
			wrote ", (self.&data)->x, ")^";
		    rfalse;
		}
	    }
	    
	    print "OK^";
	}
	else
	{
	    print "Failed to write file^";
	}
	
	rtrue;
    ];


