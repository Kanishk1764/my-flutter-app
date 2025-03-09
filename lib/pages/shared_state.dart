// Enum for tracking job status
enum JobStatus {
  pending,
  accepted,
  payment_requested,
  payment_processing,
  payment_completed,
  workdone
}

// Mock data store for jobs and transactions
class AppState {
  static final Map<String, Map<String, dynamic>> jobs = {};
  static final Map<String, List<Map<String, dynamic>>> userTransactions = {};
  static final Map<String, List<Map<String, dynamic>>> workerTransactions = {};
  
  // Add job payment details
  static void addJobPayment(String jobId, Map<String, dynamic> paymentDetails) {
    if (jobs.containsKey(jobId)) {
      jobs[jobId]?['payment'] = paymentDetails;
    }
  }
  
  // Update job status
  static void updateJobStatus(String jobId, JobStatus status) {
    if (jobs.containsKey(jobId)) {
      jobs[jobId]?['status'] = status.name;
    }
  }
  
  // Add transaction records
  static void addTransaction({
    required String userId,
    required String workerId,
    required String orderId,
    required double amount,
    required String jobId,
    required String paymentMethod,
  }) {
    // User transaction
    final userTransaction = {
      'amount': amount,
      'timestamp': DateTime.now(),
      'type': 'payment',
      'paymentMethod': paymentMethod,
      'jobId': jobId,
      'orderId': orderId,
      'workerId': workerId,
    };
    
    if (!userTransactions.containsKey(userId)) {
      userTransactions[userId] = [];
    }
    userTransactions[userId]?.add(userTransaction);
    
    // Worker transaction (with escrow)
    final workerTransaction = {
      'amount': amount,
      'timestamp': DateTime.now(),
      'type': 'earning',
      'paymentMethod': paymentMethod,
      'jobId': jobId,
      'orderId': orderId,
      'userId': userId,
      'status': 'in_escrow',
      'escrowReleaseDate': DateTime.now().add(Duration(days: 2)),
    };
    
    if (!workerTransactions.containsKey(workerId)) {
      workerTransactions[workerId] = [];
    }
    workerTransactions[workerId]?.add(workerTransaction);
  }
}
