library(stringr)
library(ggplot2)
library(lsr)
                                        # This script summaries the global profiles
# For the moment it shows only the time in microseconds of each method and
# the percentage of time .

args <- commandArgs(trailingOnly = TRUE)

# Only show 4 digits for decimal part
#options(scipen=999,digits = 4)

# kernel version
kversion <- args[1]

main_dir <- "Distem_expe"
sum_walltime <- function(kind)
{

    nodes <- c(8,16,32,64)
    files <- c()
    for(num in nodes){
        files <- c(files,system(paste("ls ",main_dir,"/profile_global_*_",kind,"_",kversion,"_",num,".txt",sep=""), intern =TRUE))
    }

    def <- data.frame()
    for(file in files){

    ## read the file as a data frame
        data = read.table(file)
        r <- "profile_global_nodes_(\\d+)_\\w+_.*_(\\d+).txt"
  
        temp_match <- str_match_all(file,r)
        vnodes <- as.numeric(temp_match[[1]][,3])
        pnodes <- as.numeric(temp_match[[1]][,2])
    
        ## It assgins meaningful names for each column 
        colnames(data) <-c('percent','exclu','inclu','num_calls','subrs','usec','name')
        ## it select the column of interesent, feel free to change it and select other columns
        relevant <- subset(data, select = c('usec','name'))
                                        # It eliminates rare methods
                                        # It aggregates all values using 'mean'
        summary_table <- aggregate(relevant[,1:1], list(relevant$name), mean)

        ## this adds the Confidence intervals
        ci <- aggregate(relevant[,1:1], list(relevant$name), ciMean)
        summary_table$ci1 <- ci$x[,1]
        summary_table$ci2 <- ci$x[,2]

                                        # It assgins meaningful names for each column 
        colnames(summary_table) <-c('method','usec','ci1','ci2')

        appli <- subset(summary_table, method == "APPLU")
        if (kind == "distem"){
            def <- rbind(def,data.frame(walltime = appli$usec, vnode= vnodes, pnode=pnodes, type = paste(vnodes/pnodes,"/node",sep=""),ci1=appli$ci1,ci2=appli$ci2))
        }else {
            def <- rbind(def,data.frame(walltime = appli$usec, vnode= vnodes, pnode=pnodes, type = "native",ci1=appli$ci1,ci2=appli$ci2))
        }
    }
    return(def)
}


final <- rbind(sum_walltime("distem"),sum_walltime("real"))

print(final)

fig <- ggplot(final, aes(factor(vnode), fill=factor(type,levels = c("native","1/node","2/node","4/node","8/node")),weight=walltime)) + geom_bar(position="dodge")

fig <-  fig  + xlab("Number of nodes")
fig <-  fig  + ylab("Execution time [usecs]")
fig <- fig + geom_errorbar(aes(ymin=ci1, ymax=ci2), width=.85,position="dodge")
fig <- fig + guides(fill=guide_legend(title="No of containers"))
fig = fig + theme_bw()+ theme(
    text = element_text(size = 18),
    legend.text = element_text(size = 15),
    axis.title.y = element_text(size = 18),
    legend.position = c(0.45,0.85)

)

ggsave(paste("execution_time-",kversion,".pdf", sep=""),plot = fig)

## # it summarizes computation methods
## cpu <- data.frame(method = c('cpu'), percent = c( appli$percent - sum(comm$percent)), usec = c(appli$usec - sum(comm$usec)))
## def <- rbind(cpu,comm)
## ddata.frame(method = c('cpu'), percent = c( appli$percent - sum(comm$percent)), usec = c(appli$usecdata.frame(method = c('cpu'), percent = c( appli$percent - sum(comm$pef


