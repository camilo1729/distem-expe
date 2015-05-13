
# This script summaries the global profiles
# For the moment it shows only the time in microseconds of each method and
# the percentage of time .

args <- commandArgs(trailingOnly = TRUE)

# Only show 4 digits for decimal part
options(scipen=999,digits = 4)

# global profile file
file <- args[1]

# read the file as a data frame
data = read.table(file)

# It assgins meaningful names for each column 
colnames(data) <-c('percent','exclu','inclu','num_calls','subrs','usec','name')
# it select the column of interesent, feel free to change it and select other columns
new_data <- subset(data, select = c('percent','usec','name'))
# It eliminates rare methods
relevant <- subset(new_data, percent > 1.0)
# It aggregates all values using 'mean'
summary_table <- aggregate(relevant[,1:2], list(relevant$name), mean)

# It assgins meaningful names for each column 
colnames(summary_table) <-c('method','percent','usec')

# It sorts the values based on percentage
summary_table[with(summary_table, order(-percent)),]

# it summarizes communication methods
communication_functions=c("MPI_Init()","MPI_Recv()","MPI_Send()","MPI_Wait()")

comm <- subset(summary_table, method %in% communication_functions)
colnames(comm) <-c('method','percent','usec')
appli <- subset(summary_table, method == "APPLU")

# it summarizes computation methods
cpu <- data.frame(method = c('cpu'), percent = c( appli$percent - sum(comm$percent)), usec = c(appli$usec - sum(comm$usec)))
def <- rbind(cpu,comm)
def


