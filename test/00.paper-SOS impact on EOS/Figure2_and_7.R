init = 0
if (init == 0) {
    init = init + 1
    source("test/main_pkgs.R")
    
    load(file_plsr)
    load(file_preseason)
    load(file_pheno_010)
    load("data/00basement_TP.rda")     
}

# GOF of PLSR SOS model
# df_pred <- foreach(l_preseason = lst_preseason, l_plsr = lst_plsr, i = icount()) %do% {
#     temp = foreach(d = l_preseason$data, ypred = t(l_plsr$SOS$ypred), j = icount()) %do% {
#         runningId(j, 1000)
#         GOF(d$EOS, ypred, include.r = TRUE)
#     } 
#     do.call(rbind, temp) %>% data.table()
# }

grps = c(1, 4, 3)
info <- foreach(l_preseason = lst_preseason[grps], l_plsr = lst_plsr[grps], i = icount()) %do% {
    d_m <- match2(l_plsr$I, l_preseason$I) # match
    temp = foreach(ypred = t(l_plsr$SOS$ypred[d_m$I_x, ]), 
                   d = l_preseason$data[d_m$I_y], j = icount()) %do% {
                       runningId(j, 1000)
                       GOF(d$EOS, ypred, include.r = TRUE)
                   } 
    
    ans = do.call(rbind, temp) %>% data.table() %>% cbind(I = d_m$x, .)
    fill_df_null(ans, ans$I, TRUE)    
}

# NON-SOS
info2 <- foreach(l_preseason = lst_preseason[grps], l_plsr = lst_plsr[grps], i = icount()) %do% {
    d_m <- match2(l_plsr$I, l_preseason$I) # match
    temp = foreach(ypred = t(l_plsr$`Non-SOS`$ypred[d_m$I_x, ]), 
                   d = l_preseason$data[d_m$I_y], j = icount()) %do% {
                       runningId(j, 1000)
                       GOF(d$EOS, ypred, include.r = TRUE)
                   } 
    
    ans = do.call(rbind, temp) %>% data.table() %>% cbind(I = d_m$x, .)
    fill_df_null(ans, ans$I, TRUE)    
}

tidy_info <- function(info) {
    r <- info %>% map(~.[, .(I, RMSE, NSE, MAE, R, R2)]) %>% 
        purrr::transpose() %>% map(as.data.table)
    lst <- r[c("RMSE", "MAE", "R2")] %>% map(~cbind(I = 1:nrow(.), .) %>% melt("I"))
    df <- melt_list(lst, "index")
    df
}

df.SOS = tidy_info(info)
df.NONSOS = tidy_info(info2)
df.diff = cbind(df.SOS[, 1:3], value = df.SOS$value - df.NONSOS$value)

indexes = c("RMSE", "MAE", "R2") %>% set_names(., .)
ngrid <- length(gridclip2_10)
SpatialPixel = gridclip2_10[, 1]


library(lattice)
library(latticeExtra)
## 1. 
# load_all("E:/Research/cmip5/Ipaper")
plsr_gof_figure(df.SOS   , outfile = "Figure2_PLSR_model_performance_SOS.pdf")
plsr_gof_figure(df.NONSOS, outfile = "Figure2_PLSR_model_performance_NonSOS.png")

## 2. diff
{
    brks0 = c(0.2, 0.5, 1) %>% c(-rev(.), 0, .)
    brks2 = c(0.05, 0.1, 0.2) %>% c(-rev(.), 0, .)
    lst_brks = list(brks0, brks0, brks2) %>% map(~c(-Inf, ., Inf))
    # df.diff$value %<>% multiply_by(-1)
    plsr_gof_figure.diff(df.diff, lst_brks, outfile = "Figure7_PLSR_model_performance_diff2.pdf")
}
