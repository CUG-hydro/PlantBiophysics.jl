"""
    Beer(k)

Beer-Lambert law for light interception.

Required inputs: `LAI` in m² m⁻².
Required meteorology data: `Ri_PAR_f`, the incident flux of atmospheric radiation in the
PAR, in W m[soil]⁻² (== J m[soil]⁻² s⁻¹).

Output: PPFD, the absorbed Photosynthetic Photon Flux Density in μmol[PAR] m[leaf]⁻² s⁻¹.
"""
struct Beer <: AbstractLight_InterceptionModel
    k::Float64
end

"""
    light_interception!_(object, meteo, constants = Constants())

Computes the light interception of an object using the Beer-Lambert law.

# Arguments

- `::Beer`: a Beer model, from the model list (*i.e.* m.light_interception)
- `models`: A `ModelList` struct holding the parameters for the model with
initialisations for `LAI` (m² m⁻²): the leaf area index.
- `status`: the status of the model, usually the model list status (*i.e.* m.status)
- `meteo`: meteorology structure, see [`Atmosphere`](@ref)
- `constants = PlantMeteo.Constants()`: physical constants. See `PlantMeteo.Constants` for more details

# Examples

```julia
m = ModelList(light_interception=Beer(0.5), status=(LAI=2.0,))

meteo = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65, Ri_PAR_f=300.0)

light_interception!(m, meteo)

m[:PPFD]
```
"""
function light_interception!_(::Beer, models, status, meteo, constants, extra=nothing)
    status.PPFD =
        meteo.Ri_PAR_f *
        exp(-models.light_interception.k * status.LAI) *
        constants.J_to_umol
end

function PlantSimEngine.inputs_(::Beer)
    (LAI=-Inf,)
end

function PlantSimEngine.outputs_(::Beer)
    (PPFD=-Inf,)
end
