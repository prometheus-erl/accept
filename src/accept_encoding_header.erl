-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.
-module(accept_encoding_header).
?MODULEDOC("For parsing and negotiating Accept-Encoding headers.").

-export([parse/1, negotiate/2]).

-include("accept.hrl").

?DOC("Accept options.").
-type accept_option() :: #accept_option{}.
?DOC("Media ranges.").
-type media_range() :: #media_range{}.
?DOC("Content codings.").
-type content_coding() :: #content_coding{}.

-export_type([accept_option/0, media_range/0, content_coding/0]).

%%====================================================================
%% Public API
%%====================================================================

?DOC("Parses Accept-Encoding header, returns a list of content_codings.").
-spec parse(AcceptString) -> Result when
    AcceptString :: binary() | string(),
    Result :: [content_coding()].
parse(AcceptString) ->
    accept_parser:map_options(fun parse_content_coding/1, AcceptString).

?DOC("Negotiates the most appropriate content_coding given the accept header").
-spec negotiate(Header, Alternatives) -> Match when
    Header :: undefined | binary() | string(),
    Alternatives :: [Alternative],
    Alternative :: binary() | {binary(), Tag},
    Tag :: any(),
    Match :: Tag | nomatch.
negotiate(undefined, Alternatives) ->
    case Alternatives of
        [H | _] -> H;
        _ -> Alternatives
    end;
negotiate([], _) ->
    <<"identity">>;
negotiate(Header, Alternatives) ->
    CCs = parse(Header),

    case CCs of
        [] -> <<"identity">>;
        _ -> negotiate_1(CCs, Alternatives)
    end.

%%====================================================================
%% Private Parts
%%====================================================================

negotiate_1(CCs, Alternatives) ->
    Alts = lists:map(
        fun(Alt) ->
            {A, Tag} = accept_neg:alt_tag(Alt),

            PA = parse_content_coding(accept_parser:ensure_string(A)),
            %% list of Alt-CC scores
            AltCCScores = lists:map(
                fun(CC) ->
                    {score_alt(CC, PA), CC}
                end,
                CCs
            ),
            %% best Content Coding match for this Alternative
            [{Score, BCC} | _] = accept_neg:sort_scored(AltCCScores),
            case Score of
                0 ->
                    {-1, Tag};
                _ ->
                    #content_coding{q = BCCQ} = BCC,
                    {BCCQ, Tag}
            end
        end,
        Alternatives
    ),

    {Q, Tag} = accept_neg:find_preferred_best(Alts),
    case Q of
        Q when Q =< 0 -> fallback_to_identity(CCs);
        _ -> Tag
    end.

parse_content_coding(#accept_option{
    option = Coding,
    q = Q,
    params = Params
}) ->
    %% RFC [https://tools.ietf.org/html/rfc7230#section-4] says
    %% that params are allowed only for 'not standard' coding
    %% this can be good TODO item
    #content_coding{
        coding = Coding,
        q = Q,
        params = Params
    };
parse_content_coding(String) ->
    parse_content_coding(accept_parser:parse_option(String)).

fallback_to_identity(CCs) ->
    %% "identity is always valid
    %% unless identity; q=0 or *;q=0
    identity_fallback(CCs, ["identity", "*"]).

identity_fallback(_, []) ->
    <<"identity">>;
identity_fallback(CCs, [C | R]) ->
    case lists:keyfind(C, #content_coding.coding, CCs) of
        #content_coding{q = 0} ->
            undefined;
        #content_coding{} ->
            <<"identity">>;
        false ->
            identity_fallback(CCs, R)
    end.

score_alt(
    #content_coding{
        coding = Coding,
        params = CCParams
    },
    #content_coding{
        coding = Coding,
        params = AltParams
    }
) ->
    4 + accept_neg:score_params(CCParams, AltParams);
score_alt(
    #content_coding{coding = "*"},
    _
) ->
    4;
score_alt(_, _) ->
    0.
