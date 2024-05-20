#Have previously done QC, filtering, and azimuth on aggregate J1994 sc data 
#split by batch. Will now assess cluster markers and make phenotype determinations 
#Redoing from code written June 2023. Making plots to include all markers simultaneously in addition 
#to saving plots that focus on one cell type (eg Treg)
#AAG 8 November 2023

library(Seurat)
library(ragg)
setwd("~/salvage_tmp/final/")
batch1 = load('./code_inputs/2023-06-06_batch1filt.rda')
azimuth_res = load('./code_inputs/2023-06-07_batch1_azimuth.rda')

tab = table(azimuth_meta$seurat_clusters, azimuth_meta$predicted.celltype.l2)


plot_list = list(
  all = FeaturePlot(filt2, raster = FALSE,  features = c('CD3E', 'CD4', 'CD8B', 'CD14', 'CD19', #General 
                                                         'LEF1', 'TCF7', 'SELL', #Naive 
                                                          'IL2RA', 'FOXP3', 'CTLA4', #Treg
                                                         'TNFRSF4', 'IL7R', #TCM
                                                         'KLRB1', 'SLC4A10', 'TRAV1-2',  #MAIT
                                                         'ITGB1', 'CCL5', 'CST7', #TEM
                                                         'MKI67' #Proliferating
  ), reduction = 'umap') 
  )

for(p in 1:length(plot_list)){
  fname = paste0('./', names(plot_list)[p], '.png')
  agg_png(filename = fname, width = 5600, height = 4800, units = 'px', scaling = 4)
  plot( plot_list[[p]])
  dev.off()
}

dot_plot_list = list(
  all = DotPlot(filt2, features = c('CD3E', 'CD4', 'CD8B', 'CD14', 'CD19', #General 
                                                        'LEF1', 'TCF7', 'SELL', #Naive 
                                                         'IL2RA', 'FOXP3', 'CTLA4', #Treg
                                                        'TNFRSF4', 'IL7R', #TCM
                                                        'KLRB1', 'SLC4A10', 'TRAV1-2',  #MAIT
                                                        'ITGB1', 'CCL5', 'CST7', #TEM
                                                        'MKI67') #Proliferating
  ) 
)

for(p in 1:length(dot_plot_list)){
  fname = paste0('./dot_', names(plot_list)[p], '.png')
  agg_png(filename = fname, width = 5600, height = 4800, units = 'px', scaling = 5)
  plot( dot_plot_list[[p]])
  dev.off()
}
#Find cluster markers and save-------
allMk = FindAllMarkers(filt2, min.pct = .5, min.diff.pct = 0.25)



bycl = split(allMk, allMk$cluster)
top100 = lapply(bycl, FUN = function(x){
  x = x[1:100, ]
  cluster = x$cluster[1]
  diff = x$pct.1 - x$pct.2
  x = x[order(diff, decreasing = TRUE),]

  return(x)
})
for(c in 1:length(top100)){
  fname = paste0('./code_outputs/Cluster', c-1, '_topMarkers.csv')
  write.csv(file = fname, top100[[c]], row.names = FALSE)
}
save(top100, tab, file = 'batch1wholemk.rda')
filt2@meta.data$azimuth = azimuth_meta$predicted.celltype.l2
DimPlot(filt2, reduction = 'umap', raster = FALSE)

tab = table(filt2@meta.data$azimuth, filt2@meta.data$seurat_clusters)
write.table(tab, file = './code_outputs/batch1_azimuth_clusters.csv', col.names = NA, sep = ',',row.names = TRUE)

meta = filt2@meta.data
umaps = as.data.frame(filt2@reductions$umap@cell.embeddings)
meta = cbind(meta, umaps)
#plot showing VDJs 
gg1 = ggplot(meta, aes(x = UMAP_1, y = UMAP_2)) + 
  geom_point(size = 0.25, color = 'grey') + 
  geom_point(size = 0.25, data = meta[which(meta$VDJ_beta == TRUE),], color = 'black') + 
  theme_prism()

fname = paste0('./code_outputs/', 'tcr-beta-vdj', '.png')
agg_png(filename = fname, width = 1200, height = 1200, units = 'px', scaling = 4)
plot(gg1)
dev.off()
#Plot showing clusters 
gg2 = ggplot(meta, aes(x = UMAP_1, y = UMAP_2, color = seurat_clusters)) + 
  geom_point(size = 0.25) + 
  theme_prism()
fname = paste0('./code_outputs/', 'seurat-clusters', '.png')
agg_png(filename = fname, width = 1200, height = 1200, units = 'px', scaling = 4)
plot(gg2)
dev.off()
#Subset filtered object based on likely T cell clusters------
to_keep = c(2,5,7,8,10,13)
filt = subset(filt2, seurat_clusters %in% to_keep)
saveRDS(filt, paste0('./code_outputs/', Sys.Date(), '_batch1filt_TCellOnly.rds'))
save(filt, file = paste0('./code_outputs/', Sys.Date(), '_batch1filt_TCellOnly.rds'))
#I think a lot of barcode hopping happens. 
tab2 = table(meta$seurat_clusters %in% to_keep, meta$VDJ_beta)
tab2 = table(meta$seurat_clusters, meta$VDJ_beta)
#19/(19 + 13k) VDJ_beta containing barcodes are kept in mu filter 
#21 / (21 + 80) non-VDJ containing barcodes are kept in my filter. 
write.table(tab2, file = './code_outputs/batch1_vdj-hopping_allcells.csv', col.names = NA, sep = ',',row.names = TRUE)

#Re cluster data on Filt.------------------------------------- 
filt <- FindVariableFeatures(filt, selection.method = 'vst', nfeatures = 5000)

top10 <- head(VariableFeatures(filt), 10)
plot1<- VariableFeaturePlot(filt)
# plot2 <- LabelPoints(plot = plot1, points = top10, repel = TRUE)
# plot2

filt <- ScaleData(filt, features = VariableFeatures(filt))
filt <- RunPCA(filt, features = VariableFeatures(filt))
plot3 <- ElbowPlot(filt, ndims = 30)

N=25
filt<- RunUMAP(filt, dims = 1:N)
filt <- FindNeighbors(filt, dims = 1:N) 
filt <- FindClusters(filt, resolution = 0.5)

#Save refined cluster labels. Added 3 Jan 2024 
m = filt@meta.data
df = data.frame(Sample = m$Sample, Barcode = m$Barcode, TCluster = m$seurat_clusters)
write.csv(df, file = './code_outputs/batch1-TCluster-Assignments.csv', row.names = FALSE, quote = FALSE)

#Now continue...
idx = match(rownames(filt@meta.data), rownames(filt2@meta.data))
filt@meta.data$azimuth = filt2@meta.data$azimuth[idx]
tab = table(filt@meta.data$seurat_clusters, filt@meta.data$azimuth)

allMk = FindAllMarkers(filt, min.pct = .5, min.diff.pct = 0.1)

bycl = split(allMk, allMk$cluster)
bycl = bycl[order(names(bycl))]
bycl = lapply(bycl, FUN = function(x){
  diff = x$pct.1 - x$pct.2
  x = x[order(diff, decreasing = TRUE),]
  return(x)
})
require(xlsx)
fname = './code_outputs/batch1-TCluster-Markers.xlsx'
write.xlsx(bycl[[1]], file = fname, append = FALSE, row.names = FALSE, 
           sheetName = paste0('Cluster', names(bycl)[1]))

for(i in 2:length(bycl)){
  write.xlsx(bycl[[i]], file = fname, append = TRUE, row.names = FALSE, 
             sheetName = paste0('Cluster', names(bycl)[i]))
}

top25 = lapply(bycl, FUN = function(x){
  x = x[1:25, ]
  cluster = x$cluster[1]
  diff = x$pct.1 - x$pct.2
  x = x[order(diff, decreasing = TRUE),]
  
  return(x)
})

for(c in 1:length(top25)){
  fname = paste0('./code_outputs/Cluster', c-1, '_topMarkers.csv')
  write.csv(file = fname, top100[[c]], row.names = FALSE)
}
meta = filt@meta.data
umaps = as.data.frame(filt@reductions$umap@cell.embeddings)
meta = cbind(meta, umaps)

gg3 = ggplot(meta, aes(x = UMAP_1, y = UMAP_2)) + 
  geom_point(size = 0.25, color = 'grey') + 
  geom_point(size = 0.25, data = meta[which(meta$VDJ_beta == TRUE),], color = 'black') + 
  theme_prism()

fname = paste0('./code_outputs/', 'tcr-beta-vdj', '.png')
agg_png(filename = fname, width = 1200, height = 1200, units = 'px', scaling = 4)
plot(gg3)
dev.off()

gg4 = ggplot(meta, aes(x = UMAP_1, y = UMAP_2, color = seurat_clusters)) + 
  geom_point(size = 0.25) + 
  theme_prism() + guides(colour = guide_legend(override.aes = list(size=2)))


fname = paste0('./code_outputs/', 'cluster-plot', '.png')
agg_png(filename = fname, width = 1600, height = 1200, units = 'px', scaling = 4)
plot(gg4)
dev.off()

#Make Feature Plots on refined clusters---------
plot_list = list(
  all = FeaturePlot(filt, raster = FALSE,  features = c('CD3E', 'CD4', 'CD8B', 'CD14', 'CD19', #General 
                                                         'LEF1', 'TCF7', 'SELL', #Naive 
                                                         'IL2RA', 'FOXP3', 'CTLA4', #Treg
                                                         'TNFRSF4', 'IL7R', #TCM
                                                         'KLRB1', 'SLC4A10', 'TRAV1-2',  #MAIT
                                                         'ITGB1', 'CCL5', 'CST7', #TEM
                                                         'MKI67' #Proliferating
  ), reduction = 'umap') 
)

for(p in 1:length(plot_list)){
  fname = paste0('./code_outputs/', names(plot_list)[p], '.png')
  agg_png(filename = fname, width = 5600, height = 4800, units = 'px', scaling = 4)
  plot( plot_list[[p]])
  dev.off()
}


dot_plot_list = list(
  all = DotPlot(filt, features = c('CD3E', 'CD4', 'CD8B', 'CD14', 'CD19', #General 
                                    'LEF1', 'TCF7', 'SELL', #Naive 
                                    'IL2RA', 'FOXP3', 'CTLA4', #Treg
                                    'TNFRSF4', 'IL7R', #TCM
                                    'KLRB1', 'SLC4A10', 'TRAV1-2',  #MAIT
                                    'ITGB1', 'CCL5', 'CST7', #TEM
                                    'MKI67') #Proliferating
  ) 
)

for(p in 1:length(dot_plot_list)){
  fname = paste0('./code_outputs/dot_', names(plot_list)[p], '.png')
  agg_png(filename = fname, width = 5600, height = 4800, units = 'px', scaling = 5)
  plot( dot_plot_list[[p]])
  dev.off()
}

tab2 = table(meta$seurat_clusters, meta$VDJ_beta)
#19/(19 + 13k) VDJ_beta containing barcodes are kept in mu filter 
#21 / (21 + 80) non-VDJ containing barcodes are kept in my filter. 
write.table(tab2, file = './code_outputs/batch1_vdj-hopping.csv', col.names = NA, sep = ',',row.names = TRUE)

tab = table(meta$seurat_clusters, meta$azimuth)
write.table(tab, file = './code_outputs/batch1_azimuth-clusters.csv', col.names = NA, sep = ',',row.names = TRUE)
#Cluster 0,1: Let be azimuth 
#Cluster 2: Let be azimuth (mostly NK) 
#Cluster 3: Let be azimuth. 
#Cluster 4: CD8 TCM
#Cluster 5: CD8 TNaive 
#Cluster 6: Let be azimuth. 
#Cluster 7: Let be azimuth. 
#Cluster 8: CD8 TEM
#Cluster 9: MAIT 
#Cluster 10: Proliferting. Let Azimuth call CD4 vs CD8. 
#Cluster 11 - 12: NK cells. 

in_10 = filt@meta.data$Barcode[which(filt@meta.data$seurat_clusters == 10)]
c10_l2 = l2_counts[, match(in_10, colnames(l2_counts))]
c10_l2 = c10_l2[grep('CD4|CD8', rownames(c10_l2)),]
CD4vCD8 = apply(c10_l2, 2, FUN = function(x){
  if(all(x == 0)){return(NA)}
  i = which(x == max(x))
 CD4_num =  length(grep('CD4', names(i)))
  CD8_num = length(grep('CD8', names(i)))
   if(CD4_num > CD8_num){return('CD4 Proliferating')}
  else if(CD8_num > CD4_num){return('CD8 Proliferating')}else{return(NA)}
})

df = data.frame(barcode = in_10, type = CD4vCD8)

filt@meta.data$aag_annot = filt@meta.data$azimuth
filt@meta.data$aag_annot[which(filt@meta.data$seurat_clusters == 10)] = df$type
filt@meta.data$aag_annot[which(filt@meta.data$seurat_clusters %in% c(11,12))] = 'NK'
filt@meta.data$aag_annot[which(filt@meta.data$seurat_clusters %in% c(9))] = 'MAIT'
filt@meta.data$aag_annot[which(filt@meta.data$seurat_clusters %in% c(8))] = 'CD8 TEM'
filt@meta.data$aag_annot[which(filt@meta.data$seurat_clusters %in% c(4))] = 'CD8 TCM'
filt@meta.data$aag_annot[which(filt@meta.data$seurat_clusters %in% c(5))] = 'CD8 Naive'

# tcell_annot = data.frame(
#   barcode = filt@meta.data$Barcode[which(filt@meta.data$VDJ_alpha | filt@meta.data$VDJ_beta)],
#     annot = filt@meta.data$aag_annot[which(filt@meta.data$VDJ_alpha | filt@meta.data$VDJ_beta)]
# )
#I don't need to require alpha or beta TCR chain to call a T cell!
tcell_annot = data.frame(
  barcode = filt@meta.data$Barcode[],
  annot = filt@meta.data$aag_annot[]
)
tcell_annot = tcell_annot[-which(tcell_annot$annot %in% c('NK', 'CD14 Mono', 'ILC', 'gdT', 'NK Proliferating', 
                                                          'NK_CD56bright', 'Platelet', 'CD16 Mono')),]
write.table(tcell_annot, row.names = F, file = paste0('./code_outputs/',Sys.Date(), '_batch1-tcell-annot.csv'), sep = ',')

#Critically, save the new seurat clusters both as csv and additional seurat object. 
