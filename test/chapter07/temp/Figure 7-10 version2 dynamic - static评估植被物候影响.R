# lai应该保留小数点后两位数字
source("test/main_pkgs.R")

file_LAI = "data-raw/lst_LAI.rda"
grid <- grid_010.TP_cliped2
id <- grid_010.TP_cliped2$id
load(file_LAI)

{
    grid <- grid_010.TP_cliped2
    ngrid <- length(grid)
    pheno_LAI <- readRDS("data-raw/pheno_smoothed_LAI (2003-2017).RDS")
    pheno_LAI <- pheno_LAI[, .(meth, I, flag, origin, SOS = TRS2.sos, POP = DER.pop, EOS = TRS6.eos)] 
    d <- pheno_LAI[, lapply(.SD, mean, na.rm = TRUE), .(I, year = year(origin)), .SDcols = c("SOS", "POP", "EOS")]
    d <- expand.grid(I = 1:ngrid, year = 2003:2017) %>% data.table() %>% merge(d, all.x = TRUE, sort = FALSE)
    
    pheno_LAI <- foreach(metric = c("SOS", "POP", "EOS") %>% set_names(., .)) %do% {
        dcast(d, I ~ year, value.var = metric)[, -1] %>% as.matrix()
    }
    pheno_LAI$year  <- 2003:2017
    lst_pheno <- list("smoothed_LAI" = pheno_LAI)
}

## -----------------------------------------------------------------------------
load(file_PML)
{
    grid_full <- get_grid(range = c(73, 105, 25, 40), cellsize=0.1, type = "vec")
    ind_TP <- raster::extract(raster(grid_full), grid_010.TP)
    
    lst_dynamic <- ncread("INPUT/PML_V2-yearly-TP_010deg (2003-2017) veg_dynamic.nc", -1, convertTo2d = TRUE, grid_type = "vec")$data %>% 
        .[c(1, 2, 10, 3)] %>% set_names(bands[-2]) %>% 
        map(~.[ind_TP, ])
    lst_static <- ncread("INPUT/PML_V2-yearly-TP_010deg (2003-2017) veg_static.nc", -1, convertTo2d = TRUE, grid_type = "vec")$data %>% 
        .[c(1, 2, 10, 3)] %>% set_names(bands[-2]) %>% 
        map(~.[ind_TP, ])
}
# lst_pheno <- readRDS(file_pheno)
years_gpp <- 2003:2017
# %% ---------------------------------------------------------------------------

grid <- grid_010.TP_cliped2
grid_010.TP@data <- data.frame(id = 1:length(grid_010.TP))
ind_full <- raster::extract(raster(grid_010.TP), grid_010.TP_cliped)
ind_lcMask <- grid$id_cliped

lst_LAI2 <- map_depth(lst_LAI, 2, ~do.call(cbind, .))

nrow <- length(ind_lcMask)
indexes <- 1:nrow %>% set_names(., .)

lst_id <- overlap_id(grid_010.TP_cliped2, TP_poly_veg)
d_id <- map(lst_id[-c(7, 10)], ~data.table(I = .x)) %>% melt_list("region")
delta_PML <- map2(lst_dynamic, lst_static, `-`)

{
    InitCluster(12)
    temp <- foreach(l = lst_pheno, i = icount()) %do% {
        info <- match2(l$year, years_gpp)
        l_pheno <- map(l[c(1,3)] %>% rm_empty, ~.[, info$I_x])

        SOS <- l_pheno$SOS
        EOS <- l_pheno$EOS
        l_PML <- map(delta_PML, ~.[ind_full, info$I_y][ind_lcMask, ])
        ET <- abind(l_PML[-1], along = 3) %>% apply_3d(FUN = rowSums2)
        Y <- c(list(ET = ET), l_PML)[c(2, 1, 3, 4, 5)]
            
        l_LAI <- map_depth(lst_LAI2, 2, ~.x[, info$I_y])
        res = foreach(LAI = l_LAI) %do% {
            X = c(list(SOS = SOS, EOS = EOS), LAI)
            foreach(j = seq_along(Y) %>% set_names(names(Y))) %do% {
                lst_data <- c(Y[j], X)
                ans <- foreach(k = indexes, icount()) %do%
                    {
                        runningId(k, 1000)
                        d <- map(lst_data, ~ .x[k, ]) %>% as.data.table()
                        pcor2(d)
                        # xs <- map(1:nrow, function(i) map(l, ~.x[i, ]) %>% as.data.table)
                    } %>% rm_empty()
            }    
        }
        l_pcor   <- map_depth(res, 3, "estimate") %>% map_depth(2, melt_cbind)
        l_pvalue <- map_depth(res, 3, "p.value") %>% map_depth(2, melt_cbind)
        list(pcor = l_pcor, pvalue = l_pvalue)
    }
    
    responsors <- c("SOS", "EOS", "gsMean", "yearMax")
    lst_pcor <- transpose(temp) %>% map(
        function(l) {
            ans <- melt_tree(l, c("type_source", "type_LAI", "response"))
            names(ans)[5:8] <- responsors
            ans
        }
    )
    save(lst_pcor, file = "chp7_version4_dynamic-static_GPP&ET_pcor.rda")
}

# grid@data <- l_PML$GPP %>% as.data.table()
# plot(grid)
load("chp7_version3_dynamic-static_GPP&ET_pcor.rda")
{    
    bands = c("GPP", "ET", "Ec", "Es", "Ei")
    bands_zh = c("总初级生产力", "蒸散发", "植被蒸腾", "土壤蒸发", "顶冠截流")
    indicator = c("生长季开始时间", "生长季结束时间", "年LAI最大值", "生长季LAI均值")

    lst <-map(lst_pcor, ~melt(.x, id.vars = c("type_source", "type_LAI", "response", "I")))
    df <- lst$pcor %>% cbind(pvalue = lst$pvalue$value) %>% plyr::mutate(mask = pvalue <= 0.1)
    df$variable %<>% as.character() %>% factor(c("SOS", "EOS", "yearMax", "gsMean"), indicator)
    df$response %<>% factor(bands, bands)
}

## 2.0 另一种制图方法卫星的平均
{
    df2 <- df[type_LAI != "raw", ]
    SpatialPixel <- grid_010.TP_cliped2
    d <- df2[, .(value = mean(value), mask), .(response, I, variable)]
    ngrid <- length(SpatialPixel)
    d_temp <- expand.grid(I = 1:ngrid, response = bands, variable = indicator) %>% data.table()
    d <- merge(d_temp, d, all.x = TRUE, sort = FALSE)
    d$response %<>% factor(bands, bands_zh)
    devices = c("jpg", "pdf")[2]
    plot_pcor_spatial3(d, SpatialPixel, devices, TRUE, prefix = "version4", 10)
}

tbl <- get_regional_sign(d, d_id, by = c("response", "region", "variable"))



### Abandoned ------------------------------------------------------------------
## 2.1 raw LAI -----------------------------------------------------------------
{
    df2 <- df[type_source %in% sources[5:7] & type_LAI == "raw", ] %>% 
        plyr::mutate(type_source = factor(type_source, sources[5:7]))
    devices = c("jpg", "pdf")[2]
    SpatialPixel <- grid_010.TP_cliped2
    plot_pcor_spatial2(df2, "GPP", SpatialPixel, devices, TRUE)
    plot_pcor_spatial2(df2, "ET", SpatialPixel, devices, TRUE)
    plot_pcor_spatial2(df2, "Ec", SpatialPixel, devices, TRUE)
    plot_pcor_spatial2(df2, "Es", SpatialPixel, devices, TRUE)
    plot_pcor_spatial2(df2, "Ei", SpatialPixel, devices, TRUE)
    
    data <- merge(df2, d_id)
    cor    <- data[is.finite(value), mean(value), .(type_source, response, variable, region)] %>% dcast2("variable", "V1")
    d_sign <- data[is.finite(value), sign_perc(value, mask), .(type_source, response, variable, region)] 
    pos <- dcast2(d_sign[, -6], "variable", "pos")
    neg <- dcast2(d_sign[, -5], "variable", "neg")
    
    write_list2xlsx(list(cor, pos, neg), "tbl_7-5 dynamic-static pcor3.xlsx")
}

## 2.2 smoothed LAI ------------------------------------------------------------
# 结果相差不太，不再展示
{
    df2 <- df[type_source %in% sources[5:7] & type_LAI == "smoothed", ] %>% 
    plyr::mutate(type_source = factor(type_source, sources[5:7]))
    devices = c("jpg", "pdf")[2]
    prefix = "smoothed_"
    SpatialPixel <- grid_010.TP_cliped2

    plot_pcor_spatial2(df2, "GPP", SpatialPixel, devices, TRUE, prefix)
    plot_pcor_spatial2(df2, "ET", SpatialPixel, devices, TRUE, prefix)
    plot_pcor_spatial2(df2, "Ec", SpatialPixel, devices, TRUE, prefix)
    plot_pcor_spatial2(df2, "Es", SpatialPixel, devices, TRUE, prefix)
}
# grid <- grid_010.TP_cliped2
# overlap_id(grid, TP_poly_veg)
