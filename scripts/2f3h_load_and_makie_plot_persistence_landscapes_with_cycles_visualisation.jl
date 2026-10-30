
using DrWatson
@quickactivate "arttopopaper"

using Pipe

"2f.jl" |> scriptsdir |> include
"LandscapesPlotting.jl" |> srcdir |> include
"MakiePlots.jl" |> srcdir |> include
"HeatmapsUtils.jl" |> srcdir |> include

# Subset of files used by 2f3ha/b/c for cycle visualisation plots
pruned_files_list = if CONFIG.DATA_SET == "pseudoart"
    [f for f in files_names if occursin("net_5013_5", f)]
else
    files_names
end

# ===-===-
do_nothing = "ok"
