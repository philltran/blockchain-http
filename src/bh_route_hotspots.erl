-module(bh_route_hotspots).

-behavior(bh_route_handler).
-behavior(bh_db_worker).

-include("bh_route_handler.hrl").

-export([prepare_conn/1, handle/3]).
%% Utilities
-export([get_hotspot_list/1,
         get_hotspot/1]).


-define(S_HOTSPOT_LIST_BEFORE, "hotspot_list_before").
-define(S_HOTSPOT_LIST, "hotspot_list").
-define(S_OWNER_HOTSPOT_LIST_BEFORE, "owner_hotspot_list_before").
-define(S_OWNER_HOTSPOT_LIST, "owner_hotspot_list").
-define(S_HOTSPOT, "hotspot").

-define(SELECT_HOTSPOT_BASE,
        "select g.block, g.address, g.owner, g.location, g.score, "
        "l.short_street, l.long_street, l.short_city, l.long_city, l.short_state, l.long_state, l.short_country, l.long_country from gateway_ledger g left join locations l on g.location = l.location ").

prepare_conn(Conn) ->
    {ok, S1} = epgsql:parse(Conn, ?S_HOTSPOT_LIST_BEFORE,
                           ?SELECT_HOTSPOT_BASE "where g.address > $1 order by first_block desc, address limit $2", []),

    {ok, S2} = epgsql:parse(Conn, ?S_HOTSPOT_LIST,
                           ?SELECT_HOTSPOT_BASE "order by first_block desc, address limit $1", []),

    {ok, S3} = epgsql:parse(Conn, ?S_OWNER_HOTSPOT_LIST_BEFORE,
                           ?SELECT_HOTSPOT_BASE "where g.owner = $1 and g.address > $2 order by first_block desc, address limit $3", []),

    {ok, S4} = epgsql:parse(Conn, ?S_OWNER_HOTSPOT_LIST,
                           ?SELECT_HOTSPOT_BASE "where g.owner = $1 order by first_block desc, address limit $2", []),

    {ok, S5} = epgsql:parse(Conn, ?S_HOTSPOT,
                           ?SELECT_HOTSPOT_BASE "where g.address = $1", []),

    #{?S_HOTSPOT_LIST_BEFORE => S1, ?S_HOTSPOT_LIST => S2,
      ?S_OWNER_HOTSPOT_LIST_BEFORE => S3, ?S_OWNER_HOTSPOT_LIST => S4,
      ?S_HOTSPOT => S5}.


handle('GET', [], Req) ->
    Args = ?GET_ARGS([owner, before, limit], Req),
    ?MK_RESPONSE(get_hotspot_list(Args));
handle('GET', [Address], _Req) ->
    ?MK_RESPONSE(get_hotspot(Address));

handle(_, _, _Req) ->
    ?RESPONSE_404.


get_hotspot_list([{owner, undefined}, {before, undefined}, {limit, Limit}]) ->
    {ok, _, Results} = ?PREPARED_QUERY(?S_HOTSPOT_LIST, [Limit]),
    {ok, hotspot_list_to_json(Results)};
get_hotspot_list([{owner, undefined}, {before, Before}, {limit, Limit}]) ->
    {ok, _, Results} = ?PREPARED_QUERY(?S_HOTSPOT_LIST_BEFORE, [Before, Limit]),
    {ok, hotspot_list_to_json(Results)};
get_hotspot_list([{owner, Owner}, {before, undefined}, {limit, Limit}]) ->
    {ok, _, Results} = ?PREPARED_QUERY(?S_OWNER_HOTSPOT_LIST, [Owner, Limit]),
    {ok, hotspot_list_to_json(Results)};
get_hotspot_list([{owner, Owner}, {before, Before}, {limit, Limit}]) ->
    {ok, _, Results} = ?PREPARED_QUERY(?S_OWNER_HOTSPOT_LIST_BEFORE, [Owner, Before, Limit]),
    {ok, hotspot_list_to_json(Results)}.


get_hotspot(Address) ->
    case ?PREPARED_QUERY(?S_HOTSPOT, [Address]) of
        {ok, _, [Result]} ->
            {ok, hotspot_to_json(Result)};
        _ ->
            {error, not_found}
    end.


%%
%% to_jaon
%%

hotspot_list_to_json(Results) ->
    lists:map(fun hotspot_to_json/1, Results).

hotspot_to_json({Block, Address, Owner, Location, Score, ShortStreet, LongStreet, ShortCity, LongCity, ShortState, LongState, ShortCountry, LongCountry}) ->
    {ok, Name} = erl_angry_purple_tiger:animal_name(Address),
    ?INSERT_LAT_LON(Location,
                    #{
                      <<"address">> => Address,
                      <<"name">> => list_to_binary(Name),
                      <<"owner">> => Owner,
                      <<"location">> => Location,
                      <<"geocode">> =>
                          #{
                            <<"short_street">> => ShortStreet,
                            <<"long_street">> => LongStreet,
                            <<"short_city">> => ShortCity,
                            <<"long_city">> => LongCity,
                            <<"short_state">> => ShortState,
                            <<"long_state">> => LongState,
                            <<"short_country">> => ShortCountry,
                            <<"long_country">> => LongCountry
                           },
                      <<"score_update_height">> => Block,
                      <<"score">> => Score
                     }).
