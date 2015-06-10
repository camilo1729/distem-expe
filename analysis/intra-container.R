


source("bin/sum_walltime.R")
library(ggplot2)


args <- commandArgs(trailingOnly = TRUE)

# Only show 4 digits for decimal part
#options(scipen=999,digits = 4)

bench <- args[1]
nodes <- c(4,8,16)
final <- rbind(sum_walltime("container",nodes),sum_walltime("native",nodes),sum_walltime("SM",nodes),sum_walltime("affinity",nodes))


distem_res<- rbind(sum_walltime("container",nodes),sum_walltime("container",nodes),sum_walltime("container",nodes))
final$overhead = ((distem_res$walltime-final$walltime)/final$walltime)*100
print(final)

fig <- ggplot(final, aes(factor(numprocess),
                         fill=factor(type,levels = c("native","container","affinity","SM")),
                         weight=walltime)) + geom_bar(position="dodge")
fig <- fig + geom_errorbar(aes(ymin=ci1, ymax=ci2), width=.85,position="dodge")
fig <-  fig  + xlab("Number of MPI processes")
fig <-  fig  + ylab("Execution time [usecs]")
fig = fig + theme_bw()+ theme(
    text = element_text(size = 20),
    legend.text = element_text(size = 20),
    legend.text = element_text(size = 15),
    legend.title=element_blank(),
    axis.title.y = element_text(size = 18),
    legend.position = c(0.85,0.85)

)

ggsave(paste("intra-container-",bench,".pdf", sep=""),plot = fig)



