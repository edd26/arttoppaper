using PyCall

pyimport_conda("numpy", "numpy")
# ===-===-===-
py"""
import numpy

def gaussian(x, sx, y=None, sy=None):
    # square Gaussian if only x values are passed
    if y == None:
        y = x
    if sy == None:
        sy = sx
    # centers
    xo = x / 2
    yo = y / 2
    # matrix of zeros
    M = numpy.zeros([y, x], dtype=float)
    # gaussian matrix
    for i in range(x):
        for j in range(y):
            M[j, i] = numpy.exp(
                -1.0
                * (
                    ((float(i) - xo) ** 2 / (2 * sx * sx))
                    + ((float(j) - yo) ** 2 / (2 * sy * sy))
                )
            )

    return M

def get_heatmap(gazepoints, dispsize, gaussianwh=200, gaussiansd=None):
    # HEATMAP
    # Gaussian
    gwh = gaussianwh
    gsdwh = gwh / 6 if (gaussiansd is None) else gaussiansd
    gaus = gaussian(gwh, gsdwh)
    # matrix of zeroes
    strt = int(numpy.round(gwh / 2))
    heatmapsize = (int(dispsize[1] + 2 * strt), int(dispsize[0] + 2 * strt))
    heatmap = numpy.zeros(heatmapsize, dtype=float)
    # create heatmap
    for i in range(0, len(gazepoints)):
        # get x and y coordinates
        x = int(strt + gazepoints[i][0] - int(gwh / 2))
        y = int(strt + gazepoints[i][1] - int(gwh / 2))
        # correct Gaussian size if either coordinate falls outside of
        # display boundaries
        if (not 0 < x < dispsize[0]) or (not 0 < y < dispsize[1]):
            hadj = [0, gwh]
            vadj = [0, gwh]
            if 0 > x:
                hadj[0] = abs(x)
                x = 0
            elif dispsize[0] < x:
                hadj[1] = gwh - int(x - dispsize[0])
            if 0 > y:
                vadj[0] = abs(y)
                y = 0
            elif dispsize[1] < y:
                vadj[1] = gwh - int(y - dispsize[1])
            # add adjusted Gaussian to the current heatmap
            try:
                heatmap[y : y + vadj[1], x : x + hadj[1]] += (
                    gaus[vadj[0] : vadj[1], hadj[0] : hadj[1]] * gazepoints[i][2]
                )
            except:
                # fixation was probably outside of display
                pass
        else:
            # add Gaussian to the current heatmap
            heatmap[y : y + gwh, x : x + gwh] += gaus * gazepoints[i][2]
    # resize heatmap
    heatmap = heatmap[strt : dispsize[1] + strt, strt : dispsize[0] + strt]
    # remove zeros
    lowbound = numpy.mean(heatmap[heatmap > 0])
    heatmap[heatmap < lowbound] = numpy.nan

    return heatmap
"""
function get_heatmap_py(view_and_img_df, space_width, space_height)
    export_df = get_gaze_df(view_and_img_df)

    gaze_data = [(r.GazeRightx, r.GazeRighty, 1) for r in eachrow(export_df)]
    gaze_heatmap = py"get_heatmap"(gaze_data, (space_width, space_height,))
    return gaze_heatmap
end

function get_heatmap_from_fixation_py(view_and_img_df, fixation, space_width, space_height)
    export_df = get_fixation_df(view_and_img_df, fixation)

    gaze_data = [(r.GazeRightx, r.GazeRighty, 1) for r in eachrow(export_df)]
    gaze_heatmap = py"get_heatmap"(gaze_data, (space_width, space_height,))
    return gaze_heatmap
end
