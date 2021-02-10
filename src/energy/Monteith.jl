"""
Struct to hold parameter and values for the energy model close to the one in
Monteith and Unsworth (2013)

# Arguments

- `aₛₕ = 2`: number of faces of the object that exchange sensible heat fluxes
- `aₛᵥ = 1`: number of faces of the object that exchange latent heat fluxes (hypostomatous => 1)
- `ε = 0.955`: emissivity of the object
- `maxiter = 10`: maximal number of iterations allowed to close the energy balance
- `ϵ = 0.01` (°C): maximum difference in object temperature between two iterations to
consider convergence

# Examples

```julia
energy_model = Monteith() # a leaf in an illuminated chamber
```
"""
Base.@kwdef struct Monteith{T,S} <: EnergyModel
    aₛₕ::S = 2
    aₛᵥ::S = 1
    ε::T = 0.955
    maxiter::S = 10
    ϵ::T = 0.01
end

"""
    net_radiation(energy::Monteith,status,photosynthesis,stomatal_conductance,meteo::Atmosphere,constants)
    net_radiation(energy::Monteith,status,photosynthesis,stomatal_conductance,meteo::Atmosphere)


Leaf energy balance according to Monteith and Unsworth (2013), and corrigendum from
Schymanski et al. (2017). The computation is close to the one from the MAESPA model (Duursma
et al., 2012, Vezy et al., 2018) here. The leaf temperature is computed iteratively to close
the energy balance using the mass flux (~ Rn - λE).

The other approach (close to Archimed model) closes the energy balance using energy flux.

# Arguments

- `energy::Monteith`: a `Monteith` struct, see [`Monteith`](@ref)
- `photosynthesis`: a photosynthesis model, see [`assimilation`](@ref) and *e.g.* [`Fvcb`](@ref)
- `stomatal_conductance`: a stomatal conductance model, see [`gs`](@ref) and *e.g.* [`Medlyn`](@ref)
- `meteo::Atmosphere`: a meteorology structure, see e.g. [`Atmosphere`](@ref)
- `constants`: a structure to hold physical constants

# Note

The skyFraction is equal to 2 if all the leaf is viewing is sky (e.g. in a controlled chamber), 1
if the leaf is *e.g.* up on the canopy where the upper side of the leaf sees the sky, and the
side bellow sees soil + other leaves that are all considered at the same temperature than the leaf,
or less than 1 if it is partly shaded.

`d` is the minimal dimension of the surface of an object in contact with the air.

# Examples

```julia
using MutableNamedTuples

meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

leaf = Leaf(geometry = AbstractGeom(0.03),
            energy = Monteith(),
            photosynthesis = Fvcb(),
            stomatal_conductance = Medlyn(0.03, 12.0),
            status = MutableNamedTuple(Tₗ = -999.0, Rn = 300.0, skyFraction = 2.0, # 2.0 for a leaf in an illuminated chamber
                                        PPFD = -999.0,Cₛ = -999.0, ψₗ = -999.0, H = -999.0, λE = -999.0,
                                        A = -999.0, Gₛ = -999.0, Cᵢ = -999.0, Gbₕ = -999.0,
                                        Dₗ = -999.0, Rₗₗ = -999.0))

net_radiation(leaf,meteo)
leaf.status.Rn
```

# References

Duursma, R. A., et B. E. Medlyn. 2012. « MAESPA: a model to study interactions between water
limitation, environmental drivers and vegetation function at tree and stand levels, with an
example application to [CO2] × drought interactions ». Geoscientific Model Development 5 (4):
919‑40. https://doi.org/10.5194/gmd-5-919-2012.

Monteith, John L., et Mike H. Unsworth. 2013. « Chapter 13 - Steady-State Heat Balance: (i)
Water Surfaces, Soil, and Vegetation ». In Principles of Environmental Physics (Fourth Edition),
edited by John L. Monteith et Mike H. Unsworth, 217‑47. Boston: Academic Press.

Schymanski, Stanislaus J., et Dani Or. 2017. « Leaf-Scale Experiments Reveal an Important
Omission in the Penman–Monteith Equation ». Hydrology and Earth System Sciences 21 (2): 685‑706.
https://doi.org/10.5194/hess-21-685-2017.

Vezy, Rémi, Mathias Christina, Olivier Roupsard, Yann Nouvellon, Remko Duursma, Belinda Medlyn,
Maxime Soma, et al. 2018. « Measuring and modelling energy partitioning in canopies of varying
complexity using MAESPA model ». Agricultural and Forest Meteorology 253‑254 (printemps): 203‑17.
https://doi.org/10.1016/j.agrformet.2018.02.005.
"""
function net_radiation(leaf::Leaf{G,I,<:Monteith,A,Gs,S},meteo::Atmosphere,constants) where {G,I,A,Gs,S}

    # Initialisations
    Tₗ = meteo.T
    Tₗ_new = zero(meteo.T)
    leaf.status.Cₛ = meteo.Cₐ
    leaf.status.Dₗ = meteo.VPD
    γˢ = Rbₕ = Δ = zero(meteo.T)

    iter = 1

    # Iterative resolution of the energy balance
    for i in 1:leaf.energy.maxiter

        # Update A, Gₛ, Cᵢ from leaf.status:
        assimilation!(leaf, meteo, constants)

        # Stomatal resistance to water vapor
        Rsᵥ = 1 / (gsc_to_gsw(mol_to_ms(leaf.status.Gₛ,meteo.T,meteo.P,constants.R,constants.K₀),
                                constants.Gsc_to_Gsw))

        # Re-computing the net radiation according to simulated leaf temperature:
        leaf.status.Rₗₗ = net_longwave_radiation(leaf.status.Tₗ,meteo.T,leaf.energy.ε,meteo.ε,
                                                leaf.status.skyFraction,constants.K₀,constants.σ)
        #= ? NB: we use the sky fraction here (0-2) instead of the view factor (0-1) because:
            - we consider both sides of the leaf at the same time (1 -> leaf sees sky on one face)
            - we consider all objects in the scene have the same temperature as the leaf
            of interest except the atmosphere. So the leaf exchange thermal energy only with
            the atmosphere.
        =#
        leaf.status.Rn += leaf.status.Rₗₗ

        # Leaf boundary conductance for heat (m s-1):
        leaf.status.Gbₕ = gbₕ_free(meteo.T, leaf.status.Tₗ, leaf.geometry.d, constants.Dₕ₀) +
                             gbₕ_forced(meteo.Wind, leaf.geometry.d)
        # NB, in MAESPA we use Rni so we add the radiation conductance also (not here)

        # Leaf boundary resistance for heat (s m-1):
        Rbₕ = 1 / leaf.status.Gbₕ

        # Leaf boundary resistance for water vapor (s m-1):
        Rbᵥ = 1 / gbh_to_gbw(leaf.status.Gbₕ)

        # Leaf boundary resistance for CO₂ (umol[CO₂] m-2 s-1):
        Gbc = ms_to_mol(leaf.status.Gbₕ,meteo.T,meteo.P,constants.R,constants.K₀) /
                constants.Gbc_to_Gbₕ

        # Update Cₛ using boundary layer conductance to CO₂ and assimilation:
        leaf.status.Cₛ = meteo.Cₐ - leaf.status.A / Gbc

        # Apparent value of psychrometer constant (kPa K−1)
        γˢ = γ_star(meteo.γ, leaf.energy.aₛₕ, leaf.energy.aₛᵥ, Rbᵥ, Rsᵥ, Rbₕ)

        # slope of the saturation vapor pressure at air temperature:
        Δ = e_sat_slope(meteo.T)

        leaf.status.λE = latent_heat(leaf.status.Rn, meteo.VPD, γˢ, Rbₕ, Δ, meteo.ρ,
                                        leaf.energy.aₛₕ, constants.Cₚ)

        # If potential evaporation is needed, here is how to compute it:
        # γˢₑ = γ_star(meteo.γ, energy.aₛₕ, 1, Rbᵥ, 1.0e-9, Rbₕ) # Rsᵥ is inf. low
        # Ev = latent_heat(leaf.status.Rn, meteo.VPD, γˢₑ, Rbₕ, Δ, meteo.ρ, energy.aₛₕ, constants.Cₚ)

        # Transpiration:
        ET = leaf.status.λE / meteo.λ

        # Vapour pressure difference between the surface and the saturation vapour pressure:
        Dₗ = ET * meteo.P / ((Rbᵥ + Rsᵥ) * leaf.energy.aₛₕ / leaf.energy.aₛᵥ)
        # ! Check this computation

        Tₗ_new = meteo.T + (leaf.status.Rn - leaf.status.λE) /
                (meteo.ρ * constants.Cₚ * (leaf.energy.aₛₕ / Rbₕ))

        if abs(Tₗ_new - leaf.status.Tₗ) <= leaf.energy.ϵ break end

        leaf.status.Tₗ = Tₗ_new

        iter += 1
    end


    H = sensible_heat(leaf.status.Rn, meteo.VPD, γˢ, Rbₕ, Δ, meteo.ρ, leaf.energy.aₛₕ, constants.Cₚ)


    nothing
    # return (Rn = Rn, Rₗₗ = Rₗₗ, Tₗ = Tₗ, H = H, λE = λE, A = An, Gₛ = Gₛ, Cᵢ = Cᵢ, Rbₕ = Rbₕ,
    #         Rbᵥ = Rbᵥ, iter = iter)
end

function net_radiation(leaf::Leaf{G,I,<:Monteith,A,Gs,S},meteo::Atmosphere) where {G,I,A,Gs,S}
    net_radiation(leaf, meteo, Constants())
end


"""
    latent_heat(Rn, VPD, γˢ, Rbₕ, Δ, ρ, aₛₕ, Cₚ)
    latent_heat(Rn, VPD, γˢ, Rbₕ, Δ, ρ, aₛₕ)

λE -the latent heat flux (W m-2)- using the Monteith and Unsworth (2013) definition corrected by
Schymanski et al. (2017), eq.22.

- `Rn` (W m-2): net radiation. Carefull: not the isothermal net radiation
- `VPD` (kPa): air vapor pressure deficit
- `γˢ` (kPa K−1): apparent value of psychrometer constant (see [`γ_star`](@ref))
- `Rbₕ` (s m-1): resistance for heat transfer by convection, i.e. resistance to sensible heat
- `Δ` (KPa K-1): rate of change of saturation vapor pressure with temperature (see [`e_sat_slope`](@ref))
- `ρ` (kg m-3): air density of moist air.
- `aₛₕ` (1,2): number of sides that exchange energy for heat (2 for leaves)
- `Cₚ` (J K-1 kg-1): specific heat of air for constant pressure

# References

Monteith, J. and Unsworth, M., 2013. Principles of environmental physics: plants, animals, and the atmosphere. Academic Press. See eq. 13.33.

Schymanski et al. (2017), Leaf-scale experiments reveal an important omission in the Penman–Monteith equation,
Hydrology and Earth System Sciences. DOI: https://doi.org/10.5194/hess-21-685-2017. See equ. 22.

# Examples

```julia
Tₐ = 20.0 ; P = 100.0 ;
ρ = air_density(Tₐ, P) # in kg m-3
Δ = e_sat_slope(Tₐ)

latent_heat(300.0, 2.0, 0.1461683, 50.0, Δ, ρ, 2.0)
```
"""
function latent_heat(Rn, VPD, γˢ, Rbₕ, Δ, ρ, aₛₕ, Cₚ)
  (Δ * Rn + ρ * Cₚ * VPD * (aₛₕ / Rbₕ)) / (Δ + γˢ)
end

function latent_heat(Rn, VPD, γˢ, Rbₕ, Δ, ρ, aₛₕ)
    latent_heat(Rn, VPD, γˢ, Rbₕ, Δ, ρ, aₛₕ, Constants().Cₚ)
end


"""
    sensible_heat(Rn, VPD, γˢ, Rbₕ, Δ, ρ, aₛₕ, Cₚ)
    sensible_heat(Rn, VPD, γˢ, Rbₕ, Δ, ρ, aₛₕ)

H -the sensible heat flux (W m-2)- using the Monteith and Unsworth (2013) definition corrected by
Schymanski et al. (2017), eq.22.

- `Rn` (W m-2): net radiation. Carefull: not the isothermal net radiation
- `VPD` (kPa): air vapor pressure deficit
- `γˢ` (kPa K−1): apparent value of psychrometer constant (see [`γ_star`](@ref))
- `Rbₕ` (s m-1): resistance for heat transfer by convection, i.e. resistance to sensible heat
- `Δ` (KPa K-1): rate of change of saturation vapor pressure with temperature (see [`e_sat_slope`](@ref))
- `ρ` (kg m-3): air density of moist air.
- `aₛₕ` (1,2): number of sides that exchange energy for heat (2 for leaves)
- `Cₚ` (J K-1 kg-1): specific heat of air for constant pressure

# References

Monteith, J. and Unsworth, M., 2013. Principles of environmental physics: plants, animals, and the atmosphere. Academic Press. See eq. 13.33.

Schymanski et al. (2017), Leaf-scale experiments reveal an important omission in the Penman–Monteith equation,
Hydrology and Earth System Sciences. DOI: https://doi.org/10.5194/hess-21-685-2017. See equ. 22.

# Examples

```julia
Tₐ = 20.0 ; P = 100.0 ;
ρ = air_density(Tₐ, P) # in kg m-3
Δ = e_sat_slope(Tₐ)

sensible_heat(300.0, 2.0, 0.1461683, 50.0, Δ, ρ, 2.0)
```
"""
function sensible_heat(Rn, VPD, γˢ, Rbₕ, Δ, ρ, aₛₕ, Cₚ)
  (γˢ * Rn - ρ * Cₚ * VPD * (aₛₕ / Rbₕ)) / (Δ + γˢ)
end

function sensible_heat(Rn, VPD, γˢ, Rbₕ, Δ, ρ, aₛₕ)
  sensible_heat(Rn, VPD, γˢ, Rbₕ, Δ, ρ, aₛₕ, Constants().Cₚ)
end
