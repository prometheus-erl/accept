-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.
-module(accept_neg).
-moduledoc false.

-export([alt_tag/1, sort_scored/1, find_preferred_best/1, score_params/2]).

%% @doc Extracts the tag from an alternative.
-spec alt_tag(term()) -> {string(), binary()}.
alt_tag(Alt) ->
    case Alt of
        {_, _} -> Alt;
        _ when is_binary(Alt) -> {accept_parser:ensure_string(Alt), Alt};
        _ -> {Alt, Alt}
    end.

%% @doc Sorts scored alternatives by score.
-spec sort_scored([{number(), term()}]) -> [{number(), term()}].
sort_scored(Scored) ->
    lists:sort(fun scored_cmp/2, Scored).

%% @doc Find alternative with the best score
%%
%% keysort is stable so order of Alternatives preserved
%% after sorting Tail has the best score.
%% However if multiple alternatives have the same score as Tail
%% we should find first best alternative to respect user's priority.
-spec find_preferred_best([{number(), term()}]) -> {number(), term()}.
find_preferred_best(Alts) ->
    Sorted = lists:keysort(1, Alts),
    [B | R] = lists:reverse(Sorted),
    find_preferred_best(B, R).

%% @doc Score parameters
-spec score_params([term()], [term()]) -> number().
score_params([], _) ->
    1;
score_params(CCParams, AltParams) when length(CCParams) == length(AltParams) ->
    case lists:sort(CCParams) == lists:sort(AltParams) of
        true -> 2;
        _ -> 0
    end;
score_params(_, _) ->
    0.

%%====================================================================
%% Private Parts
%%====================================================================

-spec scored_cmp({number(), term()}, {number(), term()}) -> boolean().
scored_cmp({S1, _}, {S2, _}) ->
    S1 > S2.

-spec find_preferred_best({number(), term()}, [{number(), term()}]) -> {number(), term()}.
find_preferred_best({Q, _}, [{Q, _} = H | R]) ->
    find_preferred_best(H, R);
find_preferred_best(B, []) ->
    B;
find_preferred_best(B, _) ->
    B.
