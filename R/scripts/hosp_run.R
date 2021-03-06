library(devtools)
library(covidcommon)
library(hospitalization)
library(readr)
library(dplyr)
library(tidyr)
library(magrittr)
library(hospitalization)
library(data.table)
library(parallel)

set.seed(123456789)

option_list = list(
  optparse::make_option(c("-c", "--config"), action="store", default=Sys.getenv("CONFIG_PATH"), type='character', help="path to the config file"),
  optparse::make_option(c("-d", "--deathrate"), action="store", default='all', type='character', help="name of the death scenario to run, or 'all' to run all of them"),
  optparse::make_option(c("-s", "--scenario"), action="store", default='all', type='character', help="name of the intervention to run, or 'all' to run all of them"),
  optparse::make_option(c("-j", "--jobs"), action="store", default=detectCores(), type='numeric', help="number of cores used")
)
opt = optparse::parse_args(optparse::OptionParser(option_list=option_list))

config <- covidcommon::load_config(opt$c)
if (is.na(config)) {
  stop("no configuration found -- please set CONFIG_PATH environment variable or use the -c command flag")
}

# set parameters for time to hospitalization, time to death, time to discharge
time_hosp_pars <- as_evaled_expression(config$hospitalization$parameters$time_hosp)
time_disch_pars <- as_evaled_expression(config$hospitalization$parameters$time_disch)
time_death_pars <- as_evaled_expression(config$hospitalization$parameters$time_death)
time_ICU_pars <- as_evaled_expression(config$hospitalization$parameters$time_ICU)
time_ICUdur_pars <- as_evaled_expression(config$hospitalization$parameters$time_ICUdur)
time_vent_pars <- as_evaled_expression(config$hospitalization$parameters$time_vent)
mean_inc <- as_evaled_expression(config$hospitalization$parameters$mean_inc)
dur_inf_shape <- as_evaled_expression(config$hospitalization$parameters$inf_shape)
dur_inf_scale <- as_evaled_expression(config$hospitalization$parameters$inf_scale)

# set death + hospitalization parameters
p_death <- as_evaled_expression(config$hospitalization$parameters$p_death)
names(p_death) = config$hospitalization$parameters$p_death_names
p_death_rate <- as_evaled_expression(config$hospitalization$parameters$p_death_rate)
p_ICU <- as_evaled_expression(config$hospitalization$parameters$p_ICU)
p_vent <- as_evaled_expression(config$hospitalization$parameters$p_vent)

# config$hospitalization$paths$output_path
cmd <- opt$d
scenario <- opt$s
ncore <- opt$j

# Verify that the cmd maps to a known p_death value
if (cmd == "all") {
  cmd <- names(p_death) # Run all of the configured hospitalization scenarios
} else if (is.na(p_death[cmd]) || is.null(p_death[cmd]) || p_death[cmd] == 0) {
  message(paste("Invalid cmd argument:", cmd, "did not match any of the named args in", paste( p_death, collapse = ", "), "\n"))
  quit("yes", status=1)
}
if (scenario == "all" ) {
  scenario <- config$interventions$scenarios
} else if (!(scenario %in% config$interventions$scenarios)) {
  message(paste("Invalid scenario argument:", scenario, "did not match any of the named args in", paste(config$interventions$scenario, collapse = ", ") , "\n"))
  quit("yes", status=1)
}

print(file.path(config$spatial_setup$base_path, config$spatial_setup$geodata))
county_dat <- read.csv(file.path(config$spatial_setup$base_path, config$spatial_setup$geodata))
print(county_dat)
county_dat$geoid <- as.character(county_dat$geoid)
county_dat$new_pop <- county_dat[[config$spatial_setup$popnodes]]
#county_dat <- make_metrop_labels(county_dat)

for (scn0 in scenario) {
  for (cmd0 in cmd) {
    data_filename <- paste0("model_output/",config$name,"_",scn0)
    cat(paste(data_filename, "\n"))
    p_hosp <- p_death[cmd0]*10
    cat(paste("Running hospitalization scenario: ", cmd0, "with p_hosp", p_hosp, "\n"))
    res_npi3 <- build_hospdeath_par(p_hosp = p_hosp,
                                    p_death = p_death_rate,
                                    p_vent = p_vent,
                                    p_ICU = p_ICU,
                                    time_hosp_pars=time_hosp_pars,
                                    time_death_pars=time_death_pars,
                                    time_disch_pars=time_disch_pars,
                                    time_ICU_pars = time_ICU_pars,
                                    time_vent_pars = time_vent_pars,
                                    time_ICUdur_pars = time_ICUdur_pars,
                                    cores = ncore,
                                    data_filename = data_filename,
                                    scenario_name = paste(cmd0,"death",sep="_")
    )
  }
}

