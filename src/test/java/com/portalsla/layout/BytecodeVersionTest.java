package com.portalsla.layout;

import org.junit.Test;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

public class BytecodeVersionTest {

    @Test
    public void projectClassesStayOnJava8() throws Exception {
        File root = new File("target/classes/com/portalsla");
        assertTrue("Compile before checking bytecode", root.isDirectory());
        List<String> offenders = new ArrayList<String>();
        scan(root, offenders);
        assertTrue(offenders.toString(), offenders.isEmpty());
    }

    @Test
    public void scannerIndexPublishesComponentsAndRest() throws Exception {
        String components = read("target/classes/META-INF/plugin-components/component");
        assertTrue(components, components.contains("com.portalsla.service.LayoutStore"));
        assertTrue(components, components.contains("com.portalsla.service.PortalSlaService"));
        assertTrue(components, components.contains("com.portalsla.servlet.EditorServlet"));
        assertTrue(components, components.contains("com.portalsla.rest.PortalResource"));
        assertTrue(components, components.contains("com.portalsla.rest.ConfigResource"));
        String spring = read("target/classes/META-INF/spring/plugin-context.xml");
        assertTrue(spring, spring.contains("atlassian-scanner:scan-indexes"));
        assertTrue(spring, spring.contains("http://www.atlassian.com/schema/atlassian-scanner/2"));
    }

    private String read(String path) throws Exception {
        File file = new File(path);
        assertTrue(path, file.isFile());
        InputStream in = new FileInputStream(file);
        try {
            byte[] data = new byte[(int) file.length()];
            int offset = 0;
            while (offset < data.length) {
                int n = in.read(data, offset, data.length - offset);
                if (n < 0) {
                    break;
                }
                offset += n;
            }
            return new String(data, "UTF-8");
        } finally {
            in.close();
        }
    }

    private void scan(File file, List<String> offenders) throws Exception {
        File[] children = file.listFiles();
        if (children == null) {
            return;
        }
        for (int i = 0; i < children.length; i++) {
            File child = children[i];
            if (child.isDirectory()) {
                scan(child, offenders);
            } else if (child.getName().endsWith(".class")) {
                int major = major(child);
                if (major != 52) {
                    offenders.add(child.getPath() + " major=" + major);
                }
            }
        }
    }

    private int major(File file) throws Exception {
        InputStream in = new FileInputStream(file);
        try {
            byte[] header = new byte[8];
            int read = in.read(header);
            assertEquals(8, read);
            return ((header[6] & 0xff) << 8) | (header[7] & 0xff);
        } finally {
            in.close();
        }
    }
}
