-module(accept_encoding_header_tests).

-include_lib("eunit/include/eunit.hrl").
-include("accept.hrl").

parse_accept_encoding_test() ->
    ?assertMatch(
        [
            #content_coding{
                coding = "compress",
                q = 1,
                params = []
            },
            #content_coding{
                coding = "gzip",
                q = 1,
                params = []
            }
        ],
        accept_encoding_header:parse("compress, gzip")
    ),

    ?assertMatch(
        [],
        accept_encoding_header:parse(<<"">>)
    ),

    ?assertMatch(
        [
            #content_coding{
                coding = "*",
                q = 1,
                params = []
            }
        ],
        accept_encoding_header:parse("*")
    ),

    ?assertMatch(
        [
            #content_coding{
                coding = "compress",
                q = 0.5,
                params = []
            },
            #content_coding{
                coding = "gzip",
                q = 1.0,
                params = []
            }
        ],
        accept_encoding_header:parse(<<"compress;q=0.5, gzip;q=1.0">>)
    ),

    ?assertMatch(
        [
            #content_coding{
                coding = "gzip",
                q = 1.0,
                params = []
            },
            #content_coding{
                coding = "identity",
                q = 0.5,
                params = []
            },
            #content_coding{
                coding = "*",
                q = 0,
                params = []
            }
        ],
        accept_encoding_header:parse("gzip;q=1.0, identity; q=0.5, *;q=0")
    ).

coding_negotiation_test() ->
    ?assertMatch(
        "compress",
        accept_encoding_header:negotiate(
            "compress, gzip",
            ["identity", "compress"]
        )
    ),
    ?assertMatch(
        <<"identity">>,
        accept_encoding_header:negotiate(
            "compress, gzip",
            ["qwe"]
        )
    ),
    ?assertMatch(
        <<"identity">>,
        accept_encoding_header:negotiate(
            "",
            ["qwe"]
        )
    ),
    ?assertMatch(
        <<"identity">>,
        accept_encoding_header:negotiate(
            "  ",
            ["qwe"]
        )
    ),
    ?assertMatch(
        undefined,
        accept_encoding_header:negotiate(
            "compress, gzip, identity;q=0",
            ["qwe"]
        )
    ),
    ?assertMatch(
        undefined,
        accept_encoding_header:negotiate(
            "compress, gzip, *;q=0",
            ["qwe"]
        )
    ),
    ?assertMatch(
        "gzip",
        accept_encoding_header:negotiate(
            "gzip;q=1.0, identity; q=0.5, *;q=0",
            ["identity", "sdc", "gzip", "compress"]
        )
    ),
    ?assertMatch(
        "gzip",
        accept_encoding_header:negotiate(
            "gzip, identity; q=0.5, *;q=0",
            ["identity", "sdc", "gzip", "compress"]
        )
    ).
