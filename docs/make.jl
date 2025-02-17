using Documenter, ContinuousWavelets
ENV["PLOTS_TEST"] = "true"
ENV["GKSwstype"] = "100"
makedocs(sitename = "ContinuousWavelets.jl",
    format = Documenter.HTML(),
    authors = "David Weber",
    clean = true,
    pages = [
        "basic usage" => "index.md",
        "Install" => "installation.md",
        "CWT" => [
            "Available Wavelet Families" => "coreType.md",
            "CWT Construction" => "CWTConstruction.md",
            "Wavelet Frequency Spacing" => "spacing.md",
            "Boundary Conditions" => "bound.md",
            "Inversion" => "inverse.md"
        ],
    ])

deploydocs(
    repo = "github.com/dsweber2/ContinuousWavelets.jl.git",
)
