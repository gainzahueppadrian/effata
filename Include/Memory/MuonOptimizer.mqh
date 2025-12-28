//+------------------------------------------------------------------+
//| MuonOptimizer.mqh                                                |
//| Muon Optimizer implementation for neural network training        |
//| Copyright 2025, Advanced AI Trading Systems                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Advanced AI Trading Systems"
#property link      "https://www.example.com"
#property version   "1.00"

#ifndef MUON_OPTIMIZER_MQH
#define MUON_OPTIMIZER_MQH

#include <Math/Math.mqh>
#include <Math/Stat/Math.mqh>

// Clase principal para el optimizador Muon
class CMuonOptimizer {
private:
   // Parámetros del optimizador
   int m_steps;
   double m_a;
   double m_b;
   double m_c;
   bool m_useClip;
   double m_clipThreshold;

   // Matrices de momento para estabilidad
   double m_firstMoment[100][100];
   double m_secondMoment[100][100];
   int m_timestep;

   // Estado interno para seguimiento
   datetime m_lastUpdate;
   double m_learningRate;
   double m_beta1;
   double m_beta2;
   double m_epsilon;

public:
   // Constructor e inicialización
   CMuonOptimizer();
   void Configure(int steps, double a, double b, double c, bool useClip, double threshold);
   void ConfigureAdamLike(double learningRate, double beta1 = 0.9, double beta2 = 0.999, double epsilon = 1e-8);

   // Métodos de optimización
   void ApplyOptimization(double &weights[], int rows, int cols, double &gradients[], double &output[]);
   void ApplyOptimization(double &gradients[], int size, double &output[]);
   void UpdateMoments(double &gradients[], int size);

   // Métodos de ortogonalización
   void ApplyOrthogonalization(double &weights[], int size, int steps = 5);
   void ApplyNewtonSchulz5(double &matrix[], int rows, int cols, double &output[]);

   // Métodos de clipping y normalización
   void ApplyClipping(double &weights[], int size);
   void NormalizeWeights(double &weights[], int size);

   // Métodos de utilidad
   double CalculateMatrixNorm(double &matrix[], int rows, int cols);
   void PrintOptimizerState();
   void Reset();

   // Métodos estáticos para operaciones matriciales
   static void MatrixMultiply(double &A[], int rowsA, int colsA,
                             double &B[], int rowsB, int colsB,
                             double &result[]);
   static void MatrixAdd(double &A[], double &B[], int size, double &result[]);
   static void MatrixScale(double &A[], double scalar, int size, double &result[]);
   static void MatrixTranspose(double &A[], int rows, int cols, double &result[]);
};

//+------------------------------------------------------------------+
//| Constructor - Inicialización del optimizador Muon              |
//+------------------------------------------------------------------+
CMuonOptimizer::CMuonOptimizer() {
   // Parámetros por defecto de Newton-Schulz
   m_steps = 5;
   m_a = 3.4445;
   m_b = -4.7750;
   m_c = 2.0315;
   m_useClip = true;
   m_clipThreshold = 20.0;

   // Parámetros de Adam-like
   m_learningRate = 0.001;
   m_beta1 = 0.9;
   m_beta2 = 0.999;
   m_epsilon = 1e-8;
   m_timestep = 0;

   // Inicializar matrices de momento
   ArrayInitialize(m_firstMoment, 0.0);
   ArrayInitialize(m_secondMoment, 0.0);

   Print("Muon Optimizer inicializado con parámetros por defecto");
   Print("Pasos de Newton-Schulz: ", m_steps);
   Print("Coeficientes: a=", DoubleToString(m_a, 4), " b=", DoubleToString(m_b, 4), " c=", DoubleToString(m_c, 4));
   Print("Clipping: ", m_useClip ? "Activado" : "Desactivado", " (Threshold=", DoubleToString(m_clipThreshold, 2), ")");
}

//+------------------------------------------------------------------+
//| Configurar parámetros específicos de Muon                      |
//+------------------------------------------------------------------+
void CMuonOptimizer::Configure(int steps, double a, double b, double c, bool useClip, double threshold) {
   m_steps = MathMax(1, steps);
   m_a = a;
   m_b = b;
   m_c = c;
   m_useClip = useClip;
   m_clipThreshold = MathMax(0.1, threshold);

   Print("Muon Optimizer configurado:");
   Print("- Pasos de Newton-Schulz: ", m_steps);
   Print("- Coeficientes: a=", DoubleToString(m_a, 4), " b=", DoubleToString(m_b, 4), " c=", DoubleToString(m_c, 4));
   Print("- Clipping: ", m_useClip ? "Activado" : "Desactivado", " (Threshold=", DoubleToString(m_clipThreshold, 2), ")");
}

//+------------------------------------------------------------------+
//| Configurar parámetros similares a Adam                          |
//+------------------------------------------------------------------+
void CMuonOptimizer::ConfigureAdamLike(double learningRate, double beta1, double beta2, double epsilon) {
   m_learningRate = MathMax(1e-6, learningRate);
   m_beta1 = MathMin(MathMax(beta1, 0.0), 0.999);
   m_beta2 = MathMin(MathMax(beta2, 0.0), 0.999);
   m_epsilon = MathMax(epsilon, 1e-10);

   Print("Parámetros Adam-like configurados:");
   Print("- Learning Rate: ", DoubleToString(m_learningRate, 6));
   Print("- Beta1: ", DoubleToString(m_beta1, 3));
   Print("- Beta2: ", DoubleToString(m_beta2, 3));
   Print("- Epsilon: ", DoubleToString(m_epsilon, 10));
}

//+------------------------------------------------------------------+
//| Aplicar optimización Muon a una matriz de pesos                |
//+------------------------------------------------------------------+
void CMuonOptimizer::ApplyOptimization(double &weights[], int rows, int cols, double &gradients[], double &output[]) {
   // Paso 1: Actualizar momentos como en Adam
   UpdateMoments(gradients, rows * cols);

   // Paso 2: Calcular actualización no sesgada
   double unbiasedGradients[10000];
   int totalSize = rows * cols;

   for(int i = 0; i < totalSize; i++) {
      double mHat = m_firstMoment[i / 100][i % 100] / (1.0 - MathPow(m_beta1, m_timestep));
      double vHat = m_secondMoment[i / 100][i % 100] / (1.0 - MathPow(m_beta2, m_timestep));
      unbiasedGradients[i] = mHat / (MathSqrt(vHat) + m_epsilon);
   }

   // Paso 3: Aplicar ortogonalización Muon
   double orthogonalized[10000];
   ApplyNewtonSchulz5(unbiasedGradients, rows, cols, orthogonalized);

   // Paso 4: Aplicar actualización a pesos
   for(int i = 0; i < totalSize; i++) {
      output[i] = weights[i] - m_learningRate * orthogonalized[i];
   }

   // Paso 5: Aplicar clipping si es necesario
   if(m_useClip) {
      ApplyClipping(output, totalSize);
   }
}

//+------------------------------------------------------------------+
//| Aplicar optimización Muon a un vector de gradientes            |
//+------------------------------------------------------------------+
void CMuonOptimizer::ApplyOptimization(double &gradients[], int size, double &output[]) {
   // Copiar gradientes a salida
   ArrayCopy(output, gradients, 0, 0, size);

   // Aplicar ortogonalización
   ApplyOrthogonalization(output, size, m_steps);

   // Aplicar clipping si es necesario
   if(m_useClip) {
      ApplyClipping(output, size);
   }
}

//+------------------------------------------------------------------+
//| Actualizar momentos para Adam-like                              |
//+------------------------------------------------------------------+
void CMuonOptimizer::UpdateMoments(double &gradients[], int size) {
   m_timestep++;

   for(int i = 0; i < size; i++) {
      int row = i / 100;
      int col = i % 100;

      // Actualizar primer momento (media)
      m_firstMoment[row][col] = m_beta1 * m_firstMoment[row][col] + (1.0 - m_beta1) * gradients[i];

      // Actualizar segundo momento (varianza no centrada)
      m_secondMoment[row][col] = m_beta2 * m_secondMoment[row][col] + (1.0 - m_beta2) * MathPow(gradients[i], 2);
   }
}

//+------------------------------------------------------------------+
//| Aplicar ortogonalización a un vector de pesos                  |
//+------------------------------------------------------------------+
void CMuonOptimizer::ApplyOrthogonalization(double &weights[], int size, int steps) {
   if(size <= 0) return;

   double X[100];
   ArrayCopy(X, weights, 0, 0, MathMin(size, 100));

   // Normalizar
   double norm = 0.0;
   for(int i = 0; i < MathMin(size, 100); i++) {
      norm += X[i] * X[i];
   }
   norm = MathSqrt(norm);

   if(norm > 0) {
      for(int i = 0; i < MathMin(size, 100); i++) {
         X[i] /= norm;
      }
   }

   // Iteraciones de Newton-Schulz
   for(int step = 0; step < steps; step++) {
      double A[100][100];
      double B[100][100];
      double newX[100];

      // Calcular A = X * X^T
      for(int i = 0; i < MathMin(size, 100); i++) {
         for(int j = 0; j < MathMin(size, 100); j++) {
            A[i][j] = 0.0;
            for(int k = 0; k < MathMin(size, 100); k++) {
               A[i][j] += X[i*100+k] * X[j*100+k];
            }
         }
      }

      // Calcular B = b*A + c*A*A
      for(int i = 0; i < MathMin(size, 100); i++) {
         for(int j = 0; j < MathMin(size, 100); j++) {
            B[i][j] = 0.0;
            for(int k = 0; k < MathMin(size, 100); k++) {
               B[i][j] += m_b * A[i][k] + m_c * A[i][k] * A[k][j];
            }
         }
      }

      // Actualizar X = a*X + B*X
      for(int i = 0; i < MathMin(size, 100); i++) {
         newX[i] = m_a * X[i];
         for(int j = 0; j < MathMin(size, 100); j++) {
            newX[i] += B[i][j] * X[j];
         }
      }

      ArrayCopy(X, newX, 0, 0, MathMin(size, 100));
   }

   // Copiar resultados de vuelta a pesos
   ArrayCopy(weights, X, 0, 0, MathMin(size, 100));
}

//+------------------------------------------------------------------+
//| Aplicar algoritmo Newton-Schulz5 a una matriz                   |
//+------------------------------------------------------------------+
void CMuonOptimizer::ApplyNewtonSchulz5(double &matrix[], int rows, int cols, double &output[]) {
   if(rows <= 0 || cols <= 0) return;

   int maxSize = MathMin(100, MathMax(rows, cols));
   double X[10000];

   // Copiar y normalizar matriz
   double norm = CalculateMatrixNorm(matrix, rows, cols);
   if(norm > 0) {
      for(int i = 0; i < rows * cols; i++) {
         X[i] = matrix[i] / norm;
      }
   } else {
      ArrayCopy(X, matrix, 0, 0, rows * cols);
   }

   // Iteraciones de Newton-Schulz
   for(int step = 0; step < m_steps; step++) {
      double A[10000];
      double B[10000];
      double newX[10000];

      // Calcular A = X * X^T
      if(rows == cols) {
         MatrixMultiply(X, rows, cols, X, cols, rows, A);
      } else {
         // Para matrices no cuadradas, usar aproximación
         for(int i = 0; i < rows * cols; i++) {
            A[i] = X[i] * X[i];
         }
      }

      // Calcular B = b*A + c*A*A
      MatrixScale(A, m_b, rows * rows, B);

      double AA[10000];
      MatrixMultiply(A, rows, rows, A, rows, rows, AA);
      double temp[10000];
      MatrixScale(AA, m_c, rows * rows, temp);
      MatrixAdd(B, temp, rows * rows, B);

      // Calcular B*X
      double BX[10000];
      MatrixMultiply(B, rows, rows, X, rows, cols, BX);

      // Actualizar X = a*X + B*X
      MatrixScale(X, m_a, rows * cols, newX);
      MatrixAdd(newX, BX, rows * cols, newX);

      ArrayCopy(X, newX, 0, 0, rows * cols);
   }

   // Copiar resultados
   ArrayCopy(output, X, 0, 0, rows * cols);

   // Aplicar clipping si es necesario
   if(m_useClip) {
      ApplyClipping(output, rows * cols);
   }
}

//+------------------------------------------------------------------+
//| Aplicar clipping a un vector de pesos                          |
//+------------------------------------------------------------------+
void CMuonOptimizer::ApplyClipping(double &weights[], int size) {
   double maxAbs = 0.0;
   for(int i = 0; i < size; i++) {
      if(MathAbs(weights[i]) > maxAbs) {
         maxAbs = MathAbs(weights[i]);
      }
   }

   if(maxAbs > m_clipThreshold) {
      double scale = m_clipThreshold / maxAbs;
      for(int i = 0; i < size; i++) {
         weights[i] *= scale;
      }
   }
}

//+------------------------------------------------------------------+
//| Normalizar un vector de pesos                                   |
//+------------------------------------------------------------------+
void CMuonOptimizer::NormalizeWeights(double &weights[], int size) {
   double norm = 0.0;
   for(int i = 0; i < size; i++) {
      norm += weights[i] * weights[i];
   }
   norm = MathSqrt(norm);

   if(norm > 0) {
      for(int i = 0; i < size; i++) {
         weights[i] /= norm;
      }
   }
}

//+------------------------------------------------------------------+
//| Calcular norma de una matriz                                    |
//+------------------------------------------------------------------+
double CMuonOptimizer::CalculateMatrixNorm(double &matrix[], int rows, int cols) {
   double sum = 0.0;
   for(int i = 0; i < rows * cols; i++) {
      sum += matrix[i] * matrix[i];
   }
   return MathSqrt(sum);
}

//+------------------------------------------------------------------+
//| Multiplicar dos matrices                                        |
//+------------------------------------------------------------------+
void CMuonOptimizer::MatrixMultiply(double &A[], int rowsA, int colsA,
                                    double &B[], int rowsB, int colsB,
                                    double &result[]) {
   if(colsA != rowsB) return;

   for(int i = 0; i < rowsA; i++) {
      for(int j = 0; j < colsB; j++) {
         double sum = 0.0;
         for(int k = 0; k < colsA; k++) {
            sum += A[i * colsA + k] * B[k * colsB + j];
         }
         result[i * colsB + j] = sum;
      }
   }
}

//+------------------------------------------------------------------+
//| Sumar dos matrices                                              |
//+------------------------------------------------------------------+
void CMuonOptimizer::MatrixAdd(double &A[], double &B[], int size, double &result[]) {
   for(int i = 0; i < size; i++) {
      result[i] = A[i] + B[i];
   }
}

//+------------------------------------------------------------------+
//| Escalar una matriz                                              |
//+------------------------------------------------------------------+
void CMuonOptimizer::MatrixScale(double &A[], double scalar, int size, double &result[]) {
   for(int i = 0; i < size; i++) {
      result[i] = A[i] * scalar;
   }
}

//+------------------------------------------------------------------+
//| Transponer una matriz                                           |
//+------------------------------------------------------------------+
void CMuonOptimizer::MatrixTranspose(double &A[], int rows, int cols, double &result[]) {
   for(int i = 0; i < rows; i++) {
      for(int j = 0; j < cols; j++) {
         result[j * rows + i] = A[i * cols + j];
      }
   }
}

//+------------------------------------------------------------------+
//| Imprimir estado del optimizador                                 |
//+------------------------------------------------------------------+
void CMuonOptimizer::PrintOptimizerState() {
   Print("=== Estado del Optimizador Muon ===");
   Print("Pasos: ", m_steps);
   Print("Coeficientes: a=", DoubleToString(m_a, 4), " b=", DoubleToString(m_b, 4), " c=", DoubleToString(m_c, 4));
   Print("Learning Rate: ", DoubleToString(m_learningRate, 6));
   Print("Timestep: ", m_timestep);
   Print("Beta1: ", DoubleToString(m_beta1, 3));
   Print("Beta2: ", DoubleToString(m_beta2, 3));
   Print("Clipping: ", m_useClip ? "Activado" : "Desactivado");
   Print("Threshold de clipping: ", DoubleToString(m_clipThreshold, 2));
   Print("===================================");
}

//+------------------------------------------------------------------+
//| Reiniciar el optimizador                                        |
//+------------------------------------------------------------------+
void CMuonOptimizer::Reset() {
   m_timestep = 0;
   ArrayInitialize(m_firstMoment, 0.0);
   ArrayInitialize(m_secondMoment, 0.0);
   Print("Muon Optimizer reiniciado");
}

#endif // MUON_OPTIMIZER_MQH