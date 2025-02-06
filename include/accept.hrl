%% generic parser structure
-record(accept_option, {
    option :: string(),
    q :: number(),
    params :: [string()]
}).

%% media range for 'Accept' field options
-record(media_range, {
    type :: string(),
    subtype :: string(),
    q :: number(),
    params :: [string()]
}).

%% content coding for 'Accept-Encoding' field options
-record(content_coding, {
    coding :: string(),
    q :: number(),
    params :: [string()]
}).
