package solanum.svm;

import com.oracle.svm.core.annotate.Substitute;
import com.oracle.svm.core.annotate.TargetClass;

// Need to reference by name since this is package-private.
//import com.google.protobuf.UnsafeUtil;


@TargetClass(className = "com.google.protobuf.UnsafeUtil")
final class Target_com_google_protobuf_UnsafeUtil {
    @Substitute
    static sun.misc.Unsafe getUnsafe() {
        return null;
    }
}


public class ProtobufSubstitutions {
    // Placeholder to make javac happy.
}
