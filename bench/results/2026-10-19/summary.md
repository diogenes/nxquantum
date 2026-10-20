### baseline_2q
| Framework lane | Mean ms/op | Std ms/op | runs |
| --- | ---: | ---: | ---: |
| nxquantum[cpu_portable] | 0.005201 | 0.000239 | 3 |
| qiskit | 0.044847 | 0.001059 | 3 |
| nxquantum[cpu_compiled] | 0.079640 | 0.000638 | 3 |
| cirq | 0.227220 | 0.004846 | 3 |
| pennylane | 0.233171 | 0.002712 | 3 |

Nx best / Qiskit ratio: 0.116x (nxquantum[cpu_portable])

### deep_6q
| Framework lane | Mean ms/op | Std ms/op | runs |
| --- | ---: | ---: | ---: |
| nxquantum[cpu_portable] | 0.029043 | 0.000667 | 3 |
| nxquantum[cpu_compiled] | 0.098077 | 0.016602 | 3 |
| qiskit | 0.150642 | 0.002209 | 3 |
| cirq | 0.551472 | 0.001334 | 3 |
| pennylane | 0.565615 | 0.003499 | 3 |

Nx best / Qiskit ratio: 0.193x (nxquantum[cpu_portable])

### batch_obs_8q
| Framework lane | Mean ms/op | Std ms/op | runs |
| --- | ---: | ---: | ---: |
| nxquantum[cpu_portable] | 0.154445 | 0.000869 | 3 |
| nxquantum[cpu_compiled] | 0.180824 | 0.000762 | 3 |
| qiskit | 0.478840 | 0.003323 | 3 |
| cirq | 2.574144 | 0.032643 | 3 |
| pennylane | 3.043099 | 0.033303 | 3 |

Nx best / Qiskit ratio: 0.323x (nxquantum[cpu_portable])

### state_reuse_8q_xy
| Framework lane | Mean ms/op | Std ms/op | runs |
| --- | ---: | ---: | ---: |
| nxquantum[cpu_compiled] | 0.001459 | 0.000013 | 3 |
| nxquantum[cpu_portable] | 0.001466 | 0.000026 | 3 |
| qiskit | 0.011847 | 0.000164 | 3 |
| cirq | 0.090226 | 0.000590 | 3 |
| pennylane | 0.093590 | 0.000412 | 3 |

Nx best / Qiskit ratio: 0.123x (nxquantum[cpu_compiled])

### sampled_counts_sparse_terms
| Framework lane | Mean ms/op | Std ms/op | runs |
| --- | ---: | ---: | ---: |
| nxquantum[cpu_portable] | 0.015364 | 0.002718 | 3 |
| cirq | 0.041615 | 0.000753 | 3 |
| pennylane | 0.041696 | 0.000571 | 3 |
| qiskit | 0.093971 | 0.000624 | 3 |
| nxquantum[cpu_compiled] | 0.098354 | 0.006320 | 3 |

Nx best / Qiskit ratio: 0.163x (nxquantum[cpu_portable])

