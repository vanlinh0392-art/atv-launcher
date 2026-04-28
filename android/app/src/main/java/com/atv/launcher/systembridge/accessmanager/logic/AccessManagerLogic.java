package com.atv.launcher.systembridge.accessmanager.logic;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

public final class AccessManagerLogic {
    private AccessManagerLogic() {
    }

    public static List<String> splitServiceIds(String raw) {
        List<String> result = new ArrayList<>();
        if (raw == null || raw.trim().isEmpty()) {
            return result;
        }
        String[] parts = raw.split(":");
        for (String part : parts) {
            if (part == null) {
                continue;
            }
            String trimmed = part.trim();
            if (!trimmed.isEmpty()) {
                result.add(trimmed);
            }
        }
        return result;
    }

    public static String joinServiceIds(Collection<String> serviceIds) {
        StringBuilder builder = new StringBuilder();
        for (String serviceId : serviceIds) {
            if (serviceId == null || serviceId.trim().isEmpty()) {
                continue;
            }
            if (builder.length() > 0) {
                builder.append(':');
            }
            builder.append(serviceId.trim());
        }
        return builder.toString();
    }

    public static String canonicalServiceId(String packageName, String className) {
        if (isBlank(packageName) || isBlank(className)) {
            return null;
        }
        String normalizedClass = className.startsWith(".")
                ? packageName + className
                : className;
        return packageName + "/" + normalizedClass;
    }

    public static LinkedHashSet<String> mergeGrant(
            Collection<String> currentEnabled,
            Collection<String> packageServices
    ) {
        LinkedHashSet<String> merged = new LinkedHashSet<>();
        addAllNonBlank(merged, currentEnabled);
        addAllNonBlank(merged, packageServices);
        return merged;
    }

    public static LinkedHashSet<String> removePackageServices(
            Collection<String> currentEnabled,
            Collection<String> knownManagedServices,
            String packageName
    ) {
        LinkedHashSet<String> removalTargets = new LinkedHashSet<>();
        if (!isBlank(packageName)) {
            addServicesForPackage(removalTargets, currentEnabled, packageName);
            addServicesForPackage(removalTargets, knownManagedServices, packageName);
        }

        LinkedHashSet<String> remaining = new LinkedHashSet<>();
        for (String currentService : currentEnabled) {
            if (isBlank(currentService) || removalTargets.contains(currentService.trim())) {
                continue;
            }
            remaining.add(currentService.trim());
        }
        return remaining;
    }

    public static LinkedHashSet<String> rebuildManagedEnabledSet(
            Collection<String> currentEnabled,
            Collection<String> storedManagedServices,
            Collection<String> managedPackages,
            Collection<String> resolvedManagedServices
    ) {
        LinkedHashSet<String> storedServices = new LinkedHashSet<>();
        addAllNonBlank(storedServices, storedManagedServices);

        LinkedHashSet<String> packages = new LinkedHashSet<>();
        addAllNonBlank(packages, managedPackages);

        LinkedHashSet<String> unrelated = new LinkedHashSet<>();
        for (String currentService : currentEnabled) {
            if (isBlank(currentService)) {
                continue;
            }
            String trimmed = currentService.trim();
            String packageName = servicePackage(trimmed);
            if (storedServices.contains(trimmed)) {
                continue;
            }
            if (!isBlank(packageName) && packages.contains(packageName)) {
                continue;
            }
            unrelated.add(trimmed);
        }
        return mergeGrant(unrelated, resolvedManagedServices);
    }

    public static LinkedHashSet<String> pruneManagedPackages(
            Collection<String> storedPackages,
            Collection<String> installedPackages
    ) {
        LinkedHashSet<String> installed = new LinkedHashSet<>();
        addAllNonBlank(installed, installedPackages);

        LinkedHashSet<String> pruned = new LinkedHashSet<>();
        for (String storedPackage : storedPackages) {
            if (isBlank(storedPackage)) {
                continue;
            }
            String trimmed = storedPackage.trim();
            if (installed.contains(trimmed)) {
                pruned.add(trimmed);
            }
        }
        return pruned;
    }

    public static LinkedHashSet<String> pruneManagedServices(
            Collection<String> storedServices,
            Collection<String> managedPackages
    ) {
        LinkedHashSet<String> packages = new LinkedHashSet<>();
        addAllNonBlank(packages, managedPackages);

        LinkedHashSet<String> pruned = new LinkedHashSet<>();
        for (String storedService : storedServices) {
            if (isBlank(storedService)) {
                continue;
            }
            String packageName = servicePackage(storedService.trim());
            if (!isBlank(packageName) && packages.contains(packageName)) {
                pruned.add(storedService.trim());
            }
        }
        return pruned;
    }

    public static boolean containsPackageService(Collection<String> serviceIds, String packageName) {
        if (isBlank(packageName)) {
            return false;
        }
        String trimmedPackage = packageName.trim();
        for (String serviceId : serviceIds) {
            if (trimmedPackage.equals(servicePackage(serviceId))) {
                return true;
            }
        }
        return false;
    }

    public static String servicePackage(String serviceId) {
        if (isBlank(serviceId)) {
            return null;
        }
        int slashIndex = serviceId.indexOf('/');
        if (slashIndex <= 0) {
            return null;
        }
        return serviceId.substring(0, slashIndex).trim();
    }

    public static void sortEntries(List<SortEntry> entries) {
        Collections.sort(entries, SORT_COMPARATOR);
    }

    private static void addServicesForPackage(Set<String> target, Collection<String> source, String packageName) {
        for (String serviceId : source) {
            if (packageName.equals(servicePackage(serviceId))) {
                target.add(serviceId.trim());
            }
        }
    }

    private static void addAllNonBlank(Set<String> target, Collection<String> source) {
        for (String value : source) {
            if (isBlank(value)) {
                continue;
            }
            target.add(value.trim());
        }
    }

    private static boolean isBlank(String value) {
        return value == null || value.trim().isEmpty();
    }

    private static final Comparator<SortEntry> SORT_COMPARATOR = (left, right) -> {
        int rankCompare = Integer.compare(rank(left), rank(right));
        if (rankCompare != 0) {
            return rankCompare;
        }
        return left.sortLabel.compareToIgnoreCase(right.sortLabel);
    };

    private static int rank(SortEntry entry) {
        if (entry.enabled) {
            return 0;
        }
        if (entry.hasAccessibilityService) {
            return 1;
        }
        return 2;
    }

    public static final class SortEntry {
        public final String sortLabel;
        public final boolean enabled;
        public final boolean hasAccessibilityService;

        public SortEntry(String sortLabel, boolean enabled, boolean hasAccessibilityService) {
            this.sortLabel = sortLabel == null ? "" : sortLabel.trim().toLowerCase(Locale.US);
            this.enabled = enabled;
            this.hasAccessibilityService = hasAccessibilityService;
        }
    }
}


