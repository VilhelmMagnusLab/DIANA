#!/usr/bin env python
import pandas as pd
import pickle
import torch
from sklearn.preprocessing import LabelEncoder
from torch import nn

# Define the Neural Network Model
class NN_Model(nn.Module):
    def __init__(self, n_input, n_output):
        super(NN_Model, self).__init__()
        self.layer_out = nn.Linear(n_input, n_output, bias=False)

    def forward(self, x):
        return self.layer_out(x)

# Define the Classifier
class NN_classifier:
    def __init__(self, model_files_path):
        # Initialize device (CUDA if available)
        self.device = torch.device("cuda:2" if torch.cuda.is_available() else "cpu")

        # Load model and auxiliary files from model_files_path
        with open(model_files_path, 'rb') as f:
            model_files = pickle.load(f)
            self.model = model_files[0]
            self.enc = model_files[1]
            self.input_features = model_files[2]

        # Load the model parameters into NN_Model
        n_input = self.model[list(self.model)[-1]].size(1)
        n_output = self.model[list(self.model)[-1]].size(0)
        self.DM = NN_Model(n_input, n_output)
        self.DM.load_state_dict(self.model)
        self.DM.to(self.device)

    def predict(self, sample):
        # Ensure sample has 'probe_id' as a column (not index)
        if sample.index.name == 'probe_id':
            sample = sample.reset_index()
        # Merge to get all expected probes, fill missing with 0
        input_dnn = self.input_features[['probe_id']].merge(
            sample[['probe_id', 'methylation_call']],
            on='probe_id', how='left'
        )
        input_dnn['methylation_call'] = input_dnn['methylation_call'].fillna(0)
        print("input_dnn shape", input_dnn.shape)
        
        # Get the methylation values and truncate to match model's expected input size
        methylation_values = input_dnn['methylation_call'].values
        # The model expects 366263 features, so truncate if we have more
        expected_features = 366263
        if len(methylation_values) > expected_features:
            methylation_values = methylation_values[:expected_features]
            print(f"Truncated input from {len(input_dnn)} to {expected_features} features")
        
        torch_tensor = torch.tensor(methylation_values, dtype=torch.float32).to(self.device)
        y_val_pred_masked = self.DM(torch_tensor)
        predictions = torch.softmax((y_val_pred_masked - y_val_pred_masked.mean()) / y_val_pred_masked.std(unbiased=False), dim=0)
        class_labels = self.enc.inverse_transform(torch.topk(predictions, len(predictions)).indices.cpu().tolist())
        return torch.topk(predictions, len(predictions)).values.tolist(), class_labels, (methylation_values != 0).sum()
