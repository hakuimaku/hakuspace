// Fit the embedded profile inside the attached surface's usable output bounds.
function attachedTaskSize(width, height, leftInset, rightInset, barHeight, oppositeInset) {
    return {width: Math.min(width * 0.40, Math.max(1, width - leftInset - rightInset)),
        height: Math.min(height * 0.40, Math.max(1, height - barHeight - oppositeInset))}
}
