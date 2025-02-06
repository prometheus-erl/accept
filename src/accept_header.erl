-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.
-module(accept_header).
?MODULEDOC("HTTP Accept header parser and content-type negotiation helper").

-export([parse/1, negotiate/2]).

-include("accept.hrl").

%%====================================================================
%% Public API
%%====================================================================

?DOC("""
Parses Accept header, returns a list of media_ranges.

```
accept_header:parse(\"text/*;q=0.3, text/html;q=0.7, text/html;level=1,\"
                    \"text/html;level=2;q=0.4, */*;q=0.5\").
[{media_range,\"text\",\"*\",0.3,[]},
 {media_range,\"text\",\"html\",0.7,[]},
 {media_range,\"text\",\"html\",1,[{\"level\",\"1\"}]},
 {media_range,\"text\",\"html\",0.4,[{\"level\",\"2\"}]},
 {media_range,\"*\",\"*\",0.5,[]}]
```
""").
-spec parse(AcceptString) -> Result when
    AcceptString :: binary() | string(),
    Result :: [accept_encoding_header:media_range()].
parse(AcceptString) ->
    accept_parser:map_options(fun parse_media_range/1, AcceptString).

?DOC("""
Negotiates the most appropriate content_type given the accept header
and a list of alternatives.

```
accept_header:negotiate(\"text/*;q=0.3, text/html;q=0.7, text/html;level=1,\"
                        \"text/html;level=2;q=0.4, */*;q=0.5\",
                        [\"text/html;level=2\", \"text/html;level-3\"]).
\"text/html;level-3\"
```
""").
-spec negotiate(Header, Alternatives) -> Match when
    Header :: BinaryOrString,
    Alternatives :: [Alternative],
    Alternative :: BinaryOrString | {BinaryOrString, Tag},
    BinaryOrString :: binary() | string(),
    Tag :: any(),
    Match :: Tag | nomatch.
negotiate(Header, Alternatives) ->
    MediaRanges = parse(Header),

    Alts = lists:map(
        fun(Alt) ->
            {A, Tag} = accept_neg:alt_tag(Alt),

            PA = parse_media_range(accept_parser:ensure_string(A)),
            %% list of Alt-MR scores
            AltMRScores = lists:map(
                fun(MR) ->
                    {score_alt(MR, PA), MR}
                end,
                MediaRanges
            ),
            %% best Media Range match for this Alternative
            [{Score, BMR} | _] = accept_neg:sort_scored(AltMRScores),
            case Score of
                0 ->
                    {-1, Tag};
                _ ->
                    #media_range{q = BMRQ} = BMR,
                    {BMRQ, Tag}
            end
        end,
        Alternatives
    ),

    {Q, Tag} = accept_neg:find_preferred_best(Alts),
    case Q of
        Q when Q =< 0 -> undefined;
        _ -> Tag
    end.

%%====================================================================
%% Private Parts
%%====================================================================

parse_media_range(#accept_option{
    option = Option,
    q = Q,
    params = Params
}) ->
    [Type, SubType] = lists:map(fun string:strip/1, string:tokens(Option, "/")),

    #media_range{
        type = Type,
        subtype = SubType,
        q = Q,
        params = Params
    };
parse_media_range(String) ->
    parse_media_range(accept_parser:parse_option(String)).

%% Alternative "text/plain; version=4"
%% text/plain; version=4 > text/plan > text/plain; n=v > text/* > */* > image/*
score_alt(
    #media_range{
        type = Type,
        subtype = SubType,
        params = MRParams
    },
    #media_range{
        type = Type,
        subtype = SubType,
        params = AltParams
    }
) ->
    8 + 4 + accept_neg:score_params(MRParams, AltParams);
score_alt(
    #media_range{
        type = Type,
        subtype = "*"
    },
    #media_range{type = Type}
) ->
    8 + 3;
score_alt(
    #media_range{type = "*"},
    _
) ->
    8;
score_alt(_, _) ->
    0.
