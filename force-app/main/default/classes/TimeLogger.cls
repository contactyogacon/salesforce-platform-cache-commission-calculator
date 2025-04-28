/**
 * Utility class for measuring execution time
 */
public class TimeLogger {
    private static Map<String, Long> startTimes = new Map<String, Long>();
    
    /**
     * Start timing an operation
     * @param operationName Name of the operation to time
     */
    public static void startTimer(String operationName) {
        startTimes.put(operationName, System.currentTimeMillis());
    }
    
    /**
     * End timing an operation and log the result
     * @param operationName Name of the operation to end timing
     * @return Duration in milliseconds
     */
    public static Long endTimer(String operationName) {
        if (!startTimes.containsKey(operationName)) {
            System.debug('Timer not started for operation: ' + operationName);
            return 0;
        }
        
        Long startTime = startTimes.get(operationName);
        Long endTime = System.currentTimeMillis();
        Long duration = endTime - startTime;
        
        System.debug('Operation: ' + operationName + ' took ' + duration + ' ms');
        return duration;
    }
}