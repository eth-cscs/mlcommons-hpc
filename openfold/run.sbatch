#!/bin/bash
#SBATCH --job-name=openfold
#SBATCH --nodes=64
#SBATCH --ntasks-per-node=4
#SBATCH --gpus-per-task=1
#SBATCH --time=8:00:00
#SBATCH --output=logs/%x_%j.log
#SBATCH --error=logs/%x_%j.err
#SBATCH -x nid005681,nid005986,nid005091,nid006201,nid006401,nid006448

echo "Job started"

set -x
cat $0

export MASTER_PORT=25678
export MASTER_ADDR=$(hostname)
export DATA_PATH=/capstor/scratch/cscs/dealmeih/ds/mlperf/data/openfold/pdb_data/
export WORLD_SIZE=$(($SLURM_NNODES * $SLURM_NTASKS_PER_NODE))
export LOCAL_WORLD_SIZE=$SLURM_NTASKS_PER_NODE

export TRAIN_ARGS="\
	--training_dirpath=$SCRATCH/mlperf/openfold/rundir \
	--pdb_mmcif_chains_filepath $DATA_PATH/pdb_mmcif/processed/chains.csv \
	--pdb_mmcif_dicts_dirpath $DATA_PATH/pdb_mmcif/processed/dicts \
	--pdb_obsolete_filepath $DATA_PATH/pdb_mmcif/processed/obsolete.dat \
	--pdb_alignments_dirpath $DATA_PATH/open_protein_set/processed/pdb_alignments \
	--initialize_parameters_from $DATA_PATH/mlperf_hpc_openfold_resumable_checkpoint.pt \
	--seed 1234567890 \
	--num_train_iters 2000 \
	--val_every_iters 40 \
	--local_batch_size 1 \
	--base_lr 1e-3 \
	--warmup_lr_init 1e-5 \
	--warmup_lr_iters 0 \
	--num_train_dataloader_workers 14 \
	--num_val_dataloader_workers 2 \
	--distributed \
	--log_every_iters 4 \
	"

srun -ul --cpu-bind=verbose,rank_ldom --environment=openfold bash -c "
	export LOCAL_RANK=\$SLURM_PROCID
	/capstor/scratch/cscs/boeschf/images/launch_wrapper python train.py $TRAIN_ARGS
"
