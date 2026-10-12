package com.portalsla;

import org.junit.Test;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;

import javax.xml.parsers.DocumentBuilderFactory;
import java.io.File;
import java.io.FileInputStream;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

public class PluginDescriptorTest {

    @Test
    public void moduleKeysAreUniqueAcrossModuleTypes() throws Exception {
        File descriptor = new File("target/classes/atlassian-plugin.xml");
        assertTrue("Filtered Atlassian plugin descriptor must exist", descriptor.isFile());

        NodeList elements = DocumentBuilderFactory.newInstance()
                .newDocumentBuilder()
                .parse(descriptor)
                .getElementsByTagName("*");
        Map<String, String> declarations = new HashMap<String, String>();

        for (int i = 0; i < elements.getLength(); i++) {
            Element element = (Element) elements.item(i);
            String tag = element.getTagName();
            if ("atlassian-plugin".equals(tag) || "label".equals(tag) || !element.hasAttribute("key")) {
                continue;
            }

            String key = element.getAttribute("key");
            String previousTag = declarations.put(key, tag);
            assertNull("Duplicate plugin key '" + key + "' in <" + previousTag + "> and <" + tag + ">",
                    previousTag);
        }
    }

    @Test
    public void russianProjectLinkUsesPropertiesEscapes() throws Exception {
        Properties properties = new Properties();
        FileInputStream in = new FileInputStream("src/main/resources/portal-sla_ru_RU.properties");
        try {
            properties.load(in);
        } finally {
            in.close();
        }
        assertEquals("SLA на портале", properties.getProperty("portal-sla.admin.link"));
    }
}