function rcnn_cache_pool5_features(imdb, varargin)
% rcnn_cache_pool5_features(imdb, varargin)
%   Computes pool5 features and saves them to disk. We compute
%   pool5 features because we can easily compute fc6 and fc7
%   features from them on-the-fly and they tend to compress better
%   than fc6 or fc7 features due to greater sparsity.
%
%   Keys that can be passed in:
%
%   start             Index of the first image in imdb to process
%   end               Index of the last image in imdb to process
%   crop_mode         Crop mode (either 'warp' or 'square')
%   crop_padding      Amount of padding in crop
%   net_file          Path to the Caffe CNN to use
%   cache_name        Path to the precomputed feature cache

% AUTORIGHTS
% ---------------------------------------------------------
% Copyright (c) 2014, Ross Girshick
% 
% This file is part of the R-CNN code and is available 
% under the terms of the Simplified BSD License provided in 
% LICENSE. Please retain this notice and LICENSE if you use 
% this file (or any portion of it) in your project.
% ---------------------------------------------------------

ip = inputParser;
ip.addRequired('imdb', @isstruct);
ip.addOptional('start', 1, @isscalar);
ip.addOptional('step', 1, @isscalar);
ip.addOptional('end', 0, @isscalar);
ip.addOptional('crop_mode', 'warp', @isstr);
ip.addOptional('crop_padding', 16, @isscalar);

ip.addOptional('image_dir', '', @isstr);
ip.addOptional('image_ext', '', @isstr);
ip.addOptional('feat_cache_dir', fullfile('feat_cache'));
ip.addOptional('net_file', './data/caffe_nets/finetune_voc_2007_trainval_iter_70k', @isstr);
ip.addOptional('mean_file', './data/caffe_nets/finetune_voc_2007_trainval_iter_70k', @isstr);
ip.addOptional('cache_name', 'v1_finetune_voc_2007_trainval_iter_70000', @isstr);
ip.addOptional('net_def_file', '', @isstr);
ip.addOptional('layer', 'fc6', @isstr);
ip.addOptional('gpu_id', 0, @isscalar);

ip.parse(imdb, varargin{:});
opts = ip.Results;

image_ids = imdb.image_ids;
if opts.end == 0
  opts.end = length(image_ids);
end

% Where to save feature cache
opts.output_dir = fullfile(opts.feat_cache_dir, opts.cache_name, imdb.dataset_name, filesep);;
mkdir_if_missing(opts.output_dir);

% Log feature extraction
timestamp = datestr(datevec(now()), 'dd.mmm.yyyy:HH.MM.SS');
diary_file = fullfile_ext(opts.output_dir, ['rcnn_cache_features_' timestamp], 'txt');
diary(diary_file);
fprintf('Logging output in %s\n', diary_file);

fprintf('\n\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
fprintf('Feature caching options:\n');
disp(opts);
fprintf('~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n\n');

% load the region of interest database
roidb = imdb.roidb_func(imdb);
caffe('set_device', opts.gpu_id);
rcnn_model = rcnn_create_model(opts.net_def_file, opts.net_file, opts.mean_file);
rcnn_model = rcnn_load_model(rcnn_model);
rcnn_model.detectors.crop_mode = opts.crop_mode;
rcnn_model.detectors.crop_padding = opts.crop_padding;

total_time = 0;
count = 0;
for i = opts.start:opts.step:opts.end
  fprintf('%s: cache features: %d/%d\n', procid(), i, opts.end);

  save_file = [opts.output_dir image_ids{i} '.mat'];
  if exist(save_file, 'file') ~= 0
    fprintf(' [already exists]\n');
    continue;
  end
  count = count + 1;

  tot_th = tic;

  d = roidb.rois(i);
  im = imread(fullfile_ext(opts.image_dir, imdb.image_ids{i}, opts.image_ext));

  th = tic;
  d.feat = rcnn_features(im, d.boxes, rcnn_model);
  fprintf(' [features: %.3fs]\n', toc(th));

  th = tic;
  save(save_file, '-struct', 'd');
  fprintf(' [saving:   %.3fs]\n', toc(th));

  total_time = total_time + toc(tot_th);
  fprintf(' [avg time: %.3fs (total: %.3fs)]\n', ...
      total_time/count, total_time);
end
