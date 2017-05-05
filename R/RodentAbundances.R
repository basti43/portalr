################### A function to summarize monthly Portal rodent species abundance ################
###################
#level summarizes by "Plot", "Treatment", or "Site"
###################
#type uses all "Rodents" species or only "Granivores"
###################
#length uses "All" plots or only "Longterm" plots (plots that have had the same treatment over the entire time series)
###################
#unknowns either removes all individuals not identified to species (unknowns=F) or sums them in an additional column (unknowns=T)
###################
#incomplete either removes all data from incomplete trapping sessions (incomplete = F) or includes them (incomplete=T) 
#(note that if level="plot" and incomplete=T, NAs will be included in periods where trapping was incomplete)
###################
#shape returns data as a "crosstab" or "flat" list
###################
#time returns data using the complete "newmoon" numbers or the original "period" numbers
###################
#' @importFrom magrittr "%>%"

library(dplyr)
library(tidyr)

#' Return normalized path for all operating systems
#'
#' @param ReferencePath a path to join with current working directory
#' @param BasePath Current working directory else path given
#'
#' @return
#' @export
#' @examples
#' FullPath('PortalData/Rodents/Portal_rodent.csv')
#' FullPath('PortalData/Rodents/Portal_rodent.csv', '~')
FullPath <- function( ReferencePath, BasePath=getwd()){
  BasePath = normalizePath(BasePath)
  Path = normalizePath(file.path(BasePath, ReferencePath), mustWork = FALSE)
  return (Path)
}



abundance <- function(path = '~', level="Site",type="Rodents",
                      length="all",unknowns=F,incomplete=F,
                      shape="crosstab",time="period") {

##########Get Data
  data_tables = loadData(path)
  rodents = data_tables[[1]]
  species = data_tables[[2]]
  trapping = data_tables[[3]]
  newmoons = data_tables[[4]]
  plots = data_tables[[5]]

##########Data cleanup --------------------------------
rodents = remove_suspect_entries(rodents)
rodents = process_unknownsp(rodents, species, unknowns)

###########Exclude non-granivores-----------------------
rodents = process_granivores(rodents, type)

###########Remove incomplete trapping sessions----------
rodents = remove_incomplete_censuses(trapping, rodents, incomplete)

###########Use only Long-term treatments --------------
rodents = filter_plots(rodents, length)

###########Summarise by Treatment ----------------------
if(level %in% c("Treatment","treatment")){
#Name plot treatments in each time period


  rodents = join_plots_to_rodents(rodents, plots)

abundances = rodents %>%
  mutate(species = factor(species)) %>% 
  group_by(period,treatment) %>%
  do(data.frame(x = table(.$species))) %>% 
  ungroup() %>% 
  select(period,treatment,species=x.Var1, abundance=x.Freq) 
}

##########Summarise by plot ----------------------------
if(level %in% c("Plot","plot")){
  trapping = filter_plots(trapping, length)
  rodents = join_trapping_to_rodents(rodents, trapping, incomplete)
  #  reduce size of trapping table
  
  abundances = rodents %>% 
  mutate(species = factor(species)) %>% 
  group_by(period,plot,Sampled) %>%                       
  do(data.frame(x = table(.$species))) %>%
  mutate(x.Freq=replace(x.Freq,Sampled==0,NA))  %>% #0->NA on untrapped plots
    ungroup() %>% 
  select(period,plot,species=x.Var1, abundance=x.Freq) 
}

##########Summarise site-wide --------------------------
if(level %in% c("Site","site")){

  abundances = rodents %>% 
  mutate(species = factor(species)) %>% 
  group_by(period) %>%
  do(data.frame(x = table(.$species))) %>% 
  ungroup() %>% 
  select(period,species=x.Var1, abundance=x.Freq) 
}

###########Switch to new moon number if time== 'newmoon'------------------
abundances = add_newmoon_code(abundances, newmoons, time)

##########Convert data to crosstab ----------------------
if(shape %in% c("Crosstab","crosstab")){
abundances = make_crosstab(abundances)
}

return(abundances)
}