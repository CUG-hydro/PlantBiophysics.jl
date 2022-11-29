"""
    arrhenius(A,Eₐ,Tₖ,Tᵣₖ,R = PlantMeteo.Constants().R)

The Arrhenius function for dependence of the rate constant of a chemical reaction.

# Arguments

- `A`: pre-exponential factor, a constant for each chemical reaction
- `Eₐ`: activation energy for the reaction (``J\\ mol^{-1}``)
- `Tₖ`: temperature (Kelvin)
- `Tᵣₖ`: reference temperature (Kelvin) at which A was measured
- `R`: universal gas constant (``J\\ mol^{-1}\\ K^{-1}``)

# Examples

```julia
using PlantBiophysics, PlantMeteo
# Importing physical constants
constants = PlantMeteo.Constants()
# Using default values for the model:
A = Fvcb()

# Computing Jmax:
arrhenius(A.JMaxRef,A.Eₐⱼ,28.0-constants.K₀,A.Tᵣ-constants.K₀,constants.R)
# ! Warning: temperatures must be given in Kelvin

# Computing Vcmax:
arrhenius(A.VcMaxRef,A.Eₐᵥ,28.0-constants.K₀,A.Tᵣ-constants.K₀,constants.R)
```
"""
function arrhenius(A, Eₐ, Tₖ, Tᵣₖ, R=PlantMeteo.Constants().R)
    A * exp(Eₐ * (Tₖ - Tᵣₖ) / (R * Tₖ * Tᵣₖ))
end


"""
    arrhenius(A,Eₐ,Tₖ,Tᵣₖ,Hd,Δₛ,R = Constants().R)

The Arrhenius function for dependence of the rate constant of a chemical reaction,
modified following equation (17) from Medlyn et al. (2002) to consider the negative effect of
very high temperatures.

# Arguments

- `A`: the pre-exponential factor, a constant for each chemical reaction
- `Eₐ`: activation energy (``J\\ mol^{-1}``), or the exponential rate of rise
 of the function (Ha in the equation of Medlyn et al. (2002))
- `Tₖ`: current temperature (Kelvin)
- `Tᵣₖ`: reference temperature (Kelvin) at which A was measured
- `Hd`: rate of decrease of the function above the optimum (called EDVJ in
[MAESPA](http://maespa.github.io/) and [plantecophys](https://remkoduursma.github.io/plantecophys/))
- `Δₛ`: entropy factor
- `R`: is the universal gas constant (``J\\ mol^{-1}\\ K^{-1}``)

References

Medlyn, B. E., E. Dreyer, D. Ellsworth, M. Forstreuter, P. C. Harley, M. U. F. Kirschbaum,
X. Le Roux, et al. 2002. « Temperature response of parameters of a biochemically based model
of photosynthesis. II. A review of experimental data ». Plant, Cell & Environment 25 (9): 1167‑79.
https://doi.org/10.1046/j.1365-3040.2002.00891.x.


# Examples

```julia
using PlantBiophysics, PlantMeteo
# Importing physical constants
constants = Constants()
# Using default values for the model:
A = Fvcb()

# Computing Jmax:
PlantBiophysics.arrhenius(A.JMaxRef,A.Eₐⱼ,28.0-constants.K₀,A.Tᵣ-constants.K₀,A.Hdⱼ,A.Δₛⱼ)
# ! Warning: temperatures must be given in Kelvin

# Computing Vcmax:
PlantBiophysics.arrhenius(A.VcMaxRef,A.Eₐᵥ,28.0-constants.K₀,A.Tᵣ-constants.K₀,A.Hdᵥ,A.Δₛᵥ)

```
"""
function arrhenius(A, Eₐ, Tₖ, Tᵣₖ, Hd, Δₛ, R=PlantMeteo.Constants().R)
    # Equation split in 3 parts for readability:
    ftk1 = arrhenius(A, Eₐ, Tₖ, Tᵣₖ, R)
    ftk2 = (1.0 + exp((Tᵣₖ * Δₛ - Hd) / (Tᵣₖ * R)))
    ftk3 = (1.0 + exp((Tₖ * Δₛ - Hd) / (Tₖ * R)))

    ftk = ftk1 * ftk2 / ftk3

    return ftk
end

"""
    Γ_star(Tₖ,Tᵣₖ,R = PlantMeteo.Constants().R)

CO₂ compensation point ``Γ^⋆`` (``μ mol\\ mol^{-1}``) according to equation (12)
from Medlyn et al. (2002).

> ``Γ^⋆`` is the [CO₂] at which oxygenation proceeds at
twice the rate of carboxylation causing photosynthetic uptake of CO2 to be exactly
compensated by photorespiratory CO₂ release (Sharkey et al., 2007).

# Notes

Could be replaced by equation (38) from Farquhar et al. (1980), but Medlyn et al. (2002)
states that ``Γ^⋆`` as a relatively low effect on the model outputs.

# Arguments

- `Tₖ` (Kelvin): current temperature
- `Tᵣₖ` (Kelvin): reference temperature at which A was measured
- `R` (``J\\ mol^{-1}\\ K^{-1}``): is the universal gas constant

# Examples

```julia
using PlantBiophysics, PlantMeteo
# Importing the physical constants:
constants = Constants()
# computing the temperature dependence of γˢ:
Γ_star(28-constants.K₀,25-constants.K₀,constants.R)
```

# References

Farquhar, G. D., S. von von Caemmerer, et J. A. Berry. 1980. « A biochemical model of
photosynthetic CO2 assimilation in leaves of C3 species ». Planta 149 (1): 78‑90.

Medlyn, B. E., E. Dreyer, D. Ellsworth, M. Forstreuter, P. C. Harley, M. U. F. Kirschbaum,
X. Le Roux, et al. 2002. « Temperature response of parameters of a biochemically based model
of photosynthesis. II. A review of experimental data ». Plant, Cell & Environment 25 (9): 1167‑79.
https://doi.org/10.1046/j.1365-3040.2002.00891.x.

Sharkey, Thomas D., Carl J. Bernacchi, Graham D. Farquhar, et Eric L. Singsaas. 2007.
« Fitting Photosynthetic Carbon Dioxide Response Curves for C3 Leaves ». Plant, Cell &
Environment 30 (9): 1035‑40. https://doi.org/10.1111/j.1365-3040.2007.01710.x.

"""
function Γ_star(Tₖ, Tᵣₖ, R=PlantMeteo.Constants().R)
    arrhenius(oftype(Tₖ, 42.75), oftype(Tₖ, 37830.0), Tₖ, Tᵣₖ, R)
end

"""
Compute the effective Michaelis–Menten coefficient for CO2 ``Km`` (``μ mol\\ mol^{-1}``) according to
Medlyn et al. (2002), equations (5) and (6).


# References

Medlyn, B. E., E. Dreyer, D. Ellsworth, M. Forstreuter, P. C. Harley, M. U. F. Kirschbaum,
X. Le Roux, et al. 2002. « Temperature response of parameters of a biochemically based model
of photosynthesis. II. A review of experimental data ». Plant, Cell & Environment 25 (9): 1167‑79.
https://doi.org/10.1046/j.1365-3040.2002.00891.x.


# Examples

```julia
# computing the temperature dependence of γˢ:
get_km(28,25,210.0)
```
"""
function get_km(Tₖ, Tᵣₖ, O₂, R=PlantMeteo.Constants().R)
    KC = arrhenius(oftype(Tₖ, 404.9), oftype(Tₖ, 79430.0), Tₖ, Tᵣₖ, R)
    KO = arrhenius(oftype(Tₖ, 278.4), oftype(Tₖ, 36380.0), Tₖ, Tᵣₖ, R)
    return KC * (1.0 + O₂ / KO)
end
