-module(accept_header_tests).

-include_lib("eunit/include/eunit.hrl").

-define(RFC_ACCEPT,
    "text/*;q=0.3, text/html;q=0.7, text/html;level=1,"
    "text/html;level=2;q=0.4, */*;q=0.5"
).

-define(CHROME_ACCEPT,
    "application/xml,application/xhtml+xml,"
    "text/html;q=0.9,text/plain;q=0.8,image/png,image/*;q=0.9,*/*;q=0.5"
).

-define(PROMETHEUS_ACCEPT,
    "application/vnd.google.protobuf;"
    "proto=io.prometheus.client.MetricFamily;encoding=delimited;q=0.7,"
    "text/plain;version=0.0.4;q=0.3,"
    "application/json;schema=\"prometheus/telemetry\";version=0.0.2;q=0.2,"
    "*/*;q=0.1"
).

-define(PROMETHEUS_PROTOBUF_FORMAT, <<
    "application/vnd.google.protobuf; "
    "proto=io.prometheus.client.MetricFamily; "
    "encoding=delimited"
>>).

-define(PROMETHEUS_TEXT_FORMAT, <<"text/plain; version=0.0.4">>).

parse_accept_test() ->
    ?assertMatch(
        [],
        accept_header:parse(<<"">>)
    ),

    ?assertMatch(
        [
            {media_range, "text", "org", 0.5, []},
            {media_range, "text", "html", 1, []},
            {media_range, "*", "*", 1, [{"name", "value"}]},
            {media_range, "*", "*", 1, [{"name", "value"}, {"name1", "value1"}]},
            {media_range, "image", "*", 1, [{"name", "value"}]},
            {media_range, "image", "png", 1, [{"name", "value"}]},
            {media_range, "image", "*", 1, [{"name", "value"}, {"name1", "value1"}]},
            {media_range, "text", "plain", 0, [{"name", "value"}]}
        ],
        accept_header:parse(
            "text/org;q=0.5,"
            "text/html,"
            "*/*;name=value,"
            "*/*;name=value;name1=value1,"
            "image/*;name=value,"
            "image/png;name=value,"
            "image/*;name=value;name1=value1,"
            "text/plain;q=qwe;name=value;orphaned"
        )
    ),

    ?assertMatch(
        [
            {media_range, "image", "*", 1, [{"name", "value"}, {"name1", "value1"}]},
            {media_range, "image", "png", 1, [{"name", "value"}]}
        ],
        accept_header:parse(
            "image/*;name=value;name1=value1,"
            "image/png;name=value"
        )
    ).

content_negotiation_test() ->
    ?assertMatch(
        "text/html;level=1",
        accept_header:negotiate(?RFC_ACCEPT, [
            "text/plain",
            "text/html;level=2",
            "image/jpeg",
            "text/html",
            "text/html;level=3",
            "text/html;level=1"
        ])
    ),

    ?assertMatch(
        "text/html",
        accept_header:negotiate(?RFC_ACCEPT, [
            "text/plain",
            "text/html;level=2",
            "image/jpeg",
            "text/html"
        ])
    ),

    ?assertMatch(
        "text/html;level=3",
        accept_header:negotiate(?RFC_ACCEPT, [
            "text/plain",
            "text/html;level=2",
            "image/jpeg",
            "text/html;level=3"
        ])
    ),

    ?assertMatch(
        "image/jpeg",
        accept_header:negotiate(?RFC_ACCEPT, [
            "text/plain",
            "text/html;level=2",
            "image/jpeg"
        ])
    ),

    ?assertMatch(
        "text/html;level=2",
        accept_header:negotiate(?RFC_ACCEPT, [
            "text/plain",
            "text/html;level=2"
        ])
    ),

    ?assertMatch(
        "text/plain",
        accept_header:negotiate(?RFC_ACCEPT, ["text/plain"])
    ),

    ?assertMatch(
        "image/png",
        accept_header:negotiate(?CHROME_ACCEPT, [
            "text/html",
            "image/png"
        ])
    ),
    ?assertMatch(
        "text/html",
        accept_header:negotiate(?CHROME_ACCEPT, [
            "text/html",
            "text/plain",
            "text/n3"
        ])
    ),
    ?assertMatch(
        "text/plain",
        accept_header:negotiate(?CHROME_ACCEPT, [
            "text/n3",
            "text/plain"
        ])
    ),
    ?assertMatch(
        "image/jpg",
        accept_header:negotiate(?CHROME_ACCEPT, [
            "text/plain",
            "image/jpg"
        ])
    ),
    ?assertMatch(
        "text/n3",
        accept_header:negotiate(?CHROME_ACCEPT, [
            "text/n3",
            "application/rdf+xml"
        ])
    ),

    ?assertMatch(
        <<"text/n3">>,
        accept_header:negotiate(
            "text/*;q=0.5",
            [<<"text/n3">>, "text/rdf+xml", "app/qwe"]
        )
    ),

    ?assertMatch(
        prometheus_protobuf_format,
        accept_header:negotiate(
            ?PROMETHEUS_ACCEPT,
            [
                {?PROMETHEUS_TEXT_FORMAT, prometheus_text_format},
                {?PROMETHEUS_PROTOBUF_FORMAT, prometheus_protobuf_format}
            ]
        )
    ),

    ?assertMatch(
        prometheus_text_format,
        accept_header:negotiate(
            ?PROMETHEUS_ACCEPT,
            [{?PROMETHEUS_TEXT_FORMAT, prometheus_text_format}]
        )
    ),

    ?assertMatch(
        undefined,
        accept_header:negotiate(<<"text/plain;q=0, text/html">>, ["text/plain"])
    ).
